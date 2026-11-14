import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../generator/arb_manager.dart';
import 'code_rewriter.dart';

/// Coordinates the full Phase 2 extraction process across the target project.
class ExtractRunner {
  /// The root directory of the target Flutter project.
  final Directory projectDir;

  /// Optional target locale to extract into.
  final String? locale;

  /// Creates a new [ExtractRunner] for [projectDir] and optional [locale].
  ExtractRunner({
    Directory? projectDir,
    this.locale,
  }) : projectDir = projectDir ?? Directory.current;

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
    await arbManager.load();

    final rewriter = CodeRewriter(
      arbManager: arbManager,
      packageName: packageName,
    );

    final libDir = Directory(p.join(projectDir.path, 'lib'));
    if (!await libDir.exists()) {
      stderr.writeln('Error: lib/ directory not found in ${projectDir.path}.');
      exitCode = 1;
      return;
    }

    stdout.writeln(
        '🔍 Scanning Dart source files in lib/ for hardcoded strings...');
    var totalFilesScanned = 0;
    var totalFilesModified = 0;
    var totalStringsExtracted = 0;
    var totalConstsRemoved = 0;

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final normalized = entity.path.replaceAll(r'\', '/');
      if (_shouldSkipFile(normalized)) {
        continue;
      }

      totalFilesScanned++;
      final originalSource = await entity.readAsString();
      final result = rewriter.rewrite(originalSource, filePath: entity.path);

      if (result.modified) {
        await entity.writeAsString(result.newContent);
        totalFilesModified++;
        totalStringsExtracted += result.stringsExtracted;
        totalConstsRemoved += result.constsRemoved;

        stdout.writeln(
          '  ✏️  Updated ${p.relative(entity.path, from: projectDir.path)} '
          '(${result.stringsExtracted} strings localized, ${result.constsRemoved} consts removed)',
        );
      }
    }

    // Save ARB entries
    await arbManager.save();
    stdout.writeln(
        '💾 Saved updated strings to ${p.relative(arbFile.path, from: projectDir.path)}.');

    stdout.writeln('''
----------------------------------------------------------------------
Extraction Summary:
  Files Scanned:   $totalFilesScanned
  Files Modified:  $totalFilesModified
  Strings Extracted: $totalStringsExtracted
  Consts Removed:    $totalConstsRemoved
----------------------------------------------------------------------''');

    // Trigger flutter gen-l10n
    await _generateLocalizations();
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

  /// Determines if a file should be skipped during scanning.
  bool _shouldSkipFile(String path) {
    if (path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.mocks.dart') ||
        path.contains('/app_localizations') ||
        path.endsWith('core/localization_helper.dart')) {
      return true;
    }
    return false;
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
            'Note: Could not run `flutter gen-l10n` automatically: ${result.stderr}');
        stdout.writeln('Please run `flutter gen-l10n` in your terminal.');
      }
    } catch (e) {
      stdout.writeln('Note: flutter command not found in environment: $e');
      stdout.writeln('Please run `flutter gen-l10n` manually.');
    }
  }
}
