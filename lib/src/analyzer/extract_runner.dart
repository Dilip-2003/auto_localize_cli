import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../generator/arb_manager.dart';
import 'ast_payload.dart';
import 'cache_manager.dart';
import 'code_rewriter.dart';
import 'directory_crawler.dart';
import 'pre_ast_filter.dart';

class _PendingFileWrite {
  final File file;
  final String relativePath;
  final String newContent;
  final int stringsExtracted;
  final int constsRemoved;

  _PendingFileWrite({
    required this.file,
    required this.relativePath,
    required this.newContent,
    required this.stringsExtracted,
    required this.constsRemoved,
  });
}

/// Coordinates the hyper-scale Phase 2 extraction pipeline across small apps
/// and massive enterprise monorepos (up to 50M+ files).
class ExtractRunner {
  /// The root directory of the target Flutter project.
  final Directory projectDir;

  /// Optional target locale to extract into.
  final String? locale;

  /// Whether to run in O(k) Git-Diff mode, scanning only modified/untracked files.
  final bool gitDiff;

  /// Whether to bypass incremental cache and force a full re-scan.
  final bool noCache;

  /// Specific target file to extract from (safety valve for isolated testing).
  final String? targetFilePath;

  /// Whether to run in Dry-Run mode (previews changes without writing to disk).
  final bool dryRun;

  /// Number of parallel worker isolates for AST parsing.
  final int workers;

  /// Creates a new [ExtractRunner].
  ExtractRunner({
    Directory? projectDir,
    this.locale,
    this.gitDiff = false,
    this.noCache = false,
    this.targetFilePath,
    this.dryRun = false,
    int? workers,
  })  : projectDir = projectDir ?? Directory.current,
        workers = workers ?? Platform.numberOfProcessors.clamp(1, 8);

  /// Runs the extraction process.
  Future<void> run() async {
    final pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      stderr.writeln('Error: pubspec.yaml not found in ${projectDir.path}.');
      stderr.writeln(
          'Please run this command from the root of a Flutter project.');
      exitCode = 1;
      return;
    }

    final pubspecContent = await pubspecFile.readAsString();
    final yaml = loadYaml(pubspecContent) as YamlMap?;
    final packageName = yaml?['name']?.toString() ?? 'app';

    final arbFile = await _resolveArbFile();
    final arbManager = ArbManager(arbFile: arbFile);

    try {
      await arbManager.load();
    } catch (_) {
      // Errors are already logged to stderr by arbManager.load()
      exitCode = 1;
      return;
    }

    final rewriter = CodeRewriter(
      arbManager: arbManager,
      packageName: packageName,
    );

    final arbStat = arbFile.existsSync() ? arbFile.statSync() : null;
    final arbSignature = arbStat != null
        ? '${arbStat.modified.microsecondsSinceEpoch}:${arbStat.size}'
        : 'missing';

    final cacheManager = IncrementalCacheManager(
      projectDir: projectDir,
      enabled: !noCache && !dryRun && targetFilePath == null,
      arbSignature: arbSignature,
    );

    final libDir = Directory(p.join(projectDir.path, 'lib'));
    final relativeArbDir =
        p.relative(arbFile.parent.path, from: projectDir.path);

    if (dryRun) {
      stdout.writeln(
          '🔍 Running in Dry-Run mode (no files will be written to disk)...');
    } else if (targetFilePath != null) {
      stdout.writeln('🔍 Extracting specifically from $targetFilePath...');
    } else if (gitDiff) {
      stdout.writeln(
          '🔍 Running in Git-Diff mode (extracting from changed/untracked files)...');
    } else {
      stdout.writeln(
          '🔍 Streaming Dart source files in lib/ for hardcoded strings...');
    }

    var totalFilesScanned = 0;
    var totalCacheHits = 0;
    var totalFastRejected = 0;
    var totalFilesParsed = 0;
    var totalFilesModified = 0;
    var totalStringsExtracted = 0;
    var totalConstsRemoved = 0;

    // Stream files either via single-file, git diff, or streaming directory walker
    Stream<File> fileStream;
    if (targetFilePath != null) {
      final absoluteTarget = p.isAbsolute(targetFilePath!)
          ? targetFilePath!
          : p.join(projectDir.path, targetFilePath!);
      final targetFile = File(absoluteTarget);
      if (!await targetFile.exists()) {
        stderr.writeln('Error: Target file not found: $targetFilePath');
        exitCode = 1;
        return;
      }
      fileStream = Stream.value(targetFile);
    } else if (gitDiff) {
      final diffFiles = await DirectoryCrawler.getGitDiffFiles(projectDir);
      if (diffFiles.isEmpty) {
        stdout.writeln('No modified or untracked Dart files found via Git.');
      }
      fileStream = Stream.fromIterable(diffFiles);
    } else {
      fileStream = DirectoryCrawler.streamDartFiles(
        rootDir: libDir,
        relativeArbDir: relativeArbDir,
      );
    }

    const batchSize = 64;
    final candidateBatch = <FileToParse>[];
    final pendingFileWrites = <_PendingFileWrite>[];
    final cleanFiles = <String>[];

    Future<void> processCurrentBatch() async {
      if (candidateBatch.isEmpty) return;

      totalFilesParsed += candidateBatch.length;
      final parsedList = await parseCandidateBatch(
        candidateBatch,
        workers: workers,
      );

      parsedList.sort((a, b) => a.filePath.compareTo(b.filePath));

      for (final parsed in parsedList) {
        final result = rewriter.applyParsedPayload(parsed);

        if (result.modified) {
          pendingFileWrites.add(
            _PendingFileWrite(
              file: File(parsed.filePath),
              relativePath: parsed.relativePath,
              newContent: result.newContent,
              stringsExtracted: result.stringsExtracted,
              constsRemoved: result.constsRemoved,
            ),
          );

          totalFilesModified++;
          totalStringsExtracted += result.stringsExtracted;
          totalConstsRemoved += result.constsRemoved;
        } else {
          cleanFiles.add(parsed.relativePath);
        }
      }

      candidateBatch.clear();
    }

    await for (final file in fileStream) {
      totalFilesScanned++;
      final relativePath = p.relative(file.path, from: projectDir.path);

      FileStat stat;
      try {
        stat = await file.stat();
      } catch (_) {
        continue;
      }

      // Check incremental cache hit
      if (targetFilePath == null &&
          !noCache &&
          !dryRun &&
          cacheManager.isFileClean(relativePath, stat)) {
        totalCacheHits++;
        continue;
      }

      String source;
      try {
        source = await file.readAsString();
      } catch (_) {
        continue;
      }

      // Pre-AST Lexical Fast-Reject Filter (<0.01ms check)
      if (targetFilePath == null &&
          !PreAstFilter.canContainLocalizableStrings(
            source,
            filePath: file.path,
          )) {
        totalFastRejected++;
        if (!dryRun) {
          cacheManager.recordFileClean(relativePath, stat);
        }
        continue;
      }

      candidateBatch.add(
        FileToParse(
          filePath: file.path,
          relativePath: relativePath,
          source: source,
          statModifiedMicros: stat.modified.microsecondsSinceEpoch,
          statSize: stat.size,
        ),
      );

      if (candidateBatch.length >= batchSize) {
        await processCurrentBatch();
      }
    }

    // Process any trailing candidates
    await processCurrentBatch();

    // Two-Phase Atomic Commit:
    if (dryRun) {
      stdout.writeln(
          '\n[DRY RUN] Preview of changes (0 files modified on disk):');
      for (final item in pendingFileWrites) {
        stdout.writeln(
          '  📝 Would update ${item.relativePath} '
          '(${item.stringsExtracted} strings, ${item.constsRemoved} consts)',
        );
      }
      stdout.writeln(
          '[DRY RUN] Would update ARB: ${p.relative(arbFile.path, from: projectDir.path)}');
    } else {
      // Phase 1: Save ARB first!
      if (totalFilesModified > 0 || totalStringsExtracted > 0) {
        await arbManager.save();
        final newArbStat = arbFile.existsSync() ? arbFile.statSync() : null;
        final newArbSignature = newArbStat != null
            ? '${newArbStat.modified.microsecondsSinceEpoch}:${newArbStat.size}'
            : 'missing';
        cacheManager.updateArbSignature(newArbSignature);
        stdout.writeln(
          '💾 Saved updated strings to ${p.relative(arbFile.path, from: projectDir.path)}.',
        );
      }

      // Phase 2: Write all modified source files to disk!
      for (final item in pendingFileWrites) {
        await item.file.writeAsString(item.newContent);
        final newStat = await item.file.stat();
        cacheManager.recordFileClean(item.relativePath, newStat);

        stdout.writeln(
          '  ✏️  Updated ${item.relativePath} '
          '(${item.stringsExtracted} strings localized, ${item.constsRemoved} consts removed)',
        );
      }

      for (final relPath in cleanFiles) {
        final f = File(p.join(projectDir.path, relPath));
        if (f.existsSync()) {
          cacheManager.recordFileClean(relPath, f.statSync());
        }
      }

      // Persist cache shards
      await cacheManager.flush();
    }

    stdout.writeln('''
----------------------------------------------------------------------
Extraction Summary:
  Files Scanned:        $totalFilesScanned
  Cache Hits (Skipped): $totalCacheHits
  Fast-Rejected:        $totalFastRejected
  Files Parsed:         $totalFilesParsed
  Files Modified:       $totalFilesModified
  Strings Extracted:    $totalStringsExtracted
  Consts Removed:       $totalConstsRemoved
----------------------------------------------------------------------''');

    // Trigger flutter gen-l10n if strings were modified or added
    if (!dryRun && (totalFilesModified > 0 || totalStringsExtracted > 0)) {
      await _generateLocalizations();
    }
  }

  /// Resolves the primary ARB file based on CLI locale, l10n.yaml, or existing files.
  Future<File> _resolveArbFile() async {
    var arbDir = 'lib/l10n';
    var templateFile = locale != null ? 'app_$locale.arb' : 'app_en.arb';

    final l10nYamlFile = File(p.join(projectDir.path, 'l10n.yaml'));
    if (await l10nYamlFile.exists()) {
      try {
        final yamlContent = await l10nYamlFile.readAsString();
        final l10nYaml = loadYaml(yamlContent) as YamlMap?;
        if (l10nYaml != null) {
          if (l10nYaml.containsKey('arb-dir')) {
            arbDir = l10nYaml['arb-dir'].toString();
          }
          if (locale == null && l10nYaml.containsKey('template-arb-file')) {
            templateFile = l10nYaml['template-arb-file'].toString();
          }
        }
      } catch (_) {}
    }

    final targetFile = File(p.join(projectDir.path, arbDir, templateFile));
    if (!await targetFile.exists()) {
      final dir = Directory(p.join(projectDir.path, arbDir));
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.endsWith('.arb')) {
            return entity;
          }
        }
      }
    }
    return targetFile;
  }

  /// Executes `flutter gen-l10n` to rebuild localization classes.
  Future<void> _generateLocalizations() async {
    stdout.writeln('⚡ Running `flutter gen-l10n`...');
    try {
      final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';
      final result = await Process.run(
        executable,
        ['gen-l10n'],
        workingDirectory: projectDir.path,
        runInShell: true,
      );

      if (result.exitCode == 0) {
        stdout.writeln('✅ AppLocalizations regenerated successfully!');
      } else {
        stdout.writeln(
          'Note: Could not run `flutter gen-l10n` automatically: ${result.stderr}',
        );
        stdout.writeln('Please run `flutter gen-l10n` in your terminal.');
      }
    } catch (e) {
      stdout.writeln('Note: flutter command not found in environment: $e');
      stdout.writeln('Please run `flutter gen-l10n` manually.');
    }
  }
}
