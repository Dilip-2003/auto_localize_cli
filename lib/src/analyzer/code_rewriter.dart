import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import '../generator/arb_manager.dart';
import 'ast_payload.dart';
import 'ast_visitor.dart';

/// Result of rewriting a single Dart file.
class RewriteResult {
  /// The file system path of the rewritten file.
  final String path;

  /// Whether the file content was modified.
  final bool modified;

  /// The updated source code content.
  final String newContent;

  /// Number of strings extracted into localization keys.
  final int stringsExtracted;

  /// Number of ancestor const keywords removed.
  final int constsRemoved;

  /// Creates a new [RewriteResult].
  const RewriteResult({
    required this.path,
    required this.modified,
    required this.newContent,
    this.stringsExtracted = 0,
    this.constsRemoved = 0,
  });
}

/// Parses Dart source code with `analyzer`, coordinates ARB key generation,
/// removes ancestor `const` keywords, and rewrites the source code bottom-to-top.
class CodeRewriter {
  /// The ARB manager handling key generation and persistence.
  final ArbManager arbManager;

  /// The root Flutter package name used for package imports.
  final String packageName;

  /// Creates a new [CodeRewriter] with [arbManager] and [packageName].
  CodeRewriter({
    required this.arbManager,
    required this.packageName,
  });

  /// Applies rewrites to a [ParsedFilePayload] that was pre-analyzed by worker isolates.
  ///
  /// Key generation and ARB insertion are performed sequentially on the main isolate
  /// to ensure 100% deterministic key collision resolution.
  RewriteResult applyParsedPayload(ParsedFilePayload payload) {
    final normalizedPath = payload.filePath.replaceAll(r'\', '/');
    if (normalizedPath.endsWith('core/localization/localization_helper.dart') ||
        normalizedPath.endsWith('core/localization_helper.dart') ||
        normalizedPath.endsWith('localization_helper.dart')) {
      return RewriteResult(
        path: payload.filePath,
        modified: false,
        newContent: payload.source,
      );
    }

    if (payload.candidates.isEmpty) {
      return RewriteResult(
        path: payload.filePath,
        modified: false,
        newContent: payload.source,
      );
    }

    final edits = <SourceEdit>[];
    var extractedCount = 0;

    for (final candidate in payload.candidates) {
      final key = arbManager.getOrAdd(
        candidate.rawValue,
        keyText: candidate.reconstructedText,
        placeholders: candidate.placeholders,
      );

      if (key != null) {
        if (candidate.customFieldGetterName != null &&
            candidate.fieldOffset != null &&
            candidate.fieldLength != null) {
          final replacement =
              'static String get ${candidate.customFieldGetterName} => l10n.$key;';
          edits.add(
            SourceEdit(
              offset: candidate.fieldOffset!,
              length: candidate.fieldLength!,
              replacement: replacement,
            ),
          );
          extractedCount++;
        } else {
          final replacement = candidate.arguments.isEmpty
              ? 'l10n.$key'
              : 'l10n.$key(${candidate.arguments.join(', ')})';

          edits.add(
            SourceEdit(
              offset: candidate.offset,
              length: candidate.length,
              replacement: replacement,
            ),
          );
          extractedCount++;
        }
      }
    }

    if (extractedCount == 0) {
      return RewriteResult(
        path: payload.filePath,
        modified: false,
        newContent: payload.source,
      );
    }

    // Add ancestor const removals
    for (final removal in payload.constRemovals) {
      edits.add(
        SourceEdit(
          offset: removal.offset,
          length: removal.length,
          replacement: removal.replacement,
        ),
      );
    }

    // Sort edits bottom-to-top (descending by offset)
    edits.sort();

    // Deduplicate any overlapping or duplicate edits
    final safeEdits = _filterOverlappingEdits(edits);

    // Apply edits bottom-to-top
    var currentContent = payload.source;
    for (final edit in safeEdits) {
      final before = currentContent.substring(0, edit.offset);
      final after = currentContent.substring(edit.offset + edit.length);
      currentContent = '$before${edit.replacement}$after';
    }

    // Ensure localization_helper import is present
    currentContent = _ensureImport(
      currentContent,
      filePath: payload.filePath,
      isPartOf: payload.isPartOf,
      partOfUri: payload.partOfUri,
      partOfLibrary: payload.partOfLibrary,
      hasHelperImport: payload.hasHelperImport,
      lastImportEnd: payload.lastImportEnd,
      lastDirectiveEnd: payload.lastDirectiveEnd,
    );

    return RewriteResult(
      path: payload.filePath,
      modified: true,
      newContent: currentContent,
      stringsExtracted: extractedCount,
      constsRemoved: payload.constRemovals.length,
    );
  }

  /// Rewrites the given [source] code for file at [filePath] synchronously.
  RewriteResult rewrite(String source, {required String filePath}) {
    final normalizedPath = filePath.replaceAll(r'\', '/');
    if (normalizedPath.endsWith('core/localization/localization_helper.dart') ||
        normalizedPath.endsWith('core/localization_helper.dart') ||
        normalizedPath.endsWith('localization_helper.dart')) {
      return RewriteResult(
        path: filePath,
        modified: false,
        newContent: source,
      );
    }

    final parsedList = parseFilesWorker([
      FileToParse(
        filePath: filePath,
        relativePath: filePath,
        source: source,
        statModifiedMicros: 0,
        statSize: 0,
      ),
    ]);

    return applyParsedPayload(parsedList.first);
  }

  /// Filters out any overlapping edits to ensure clean source rewriting.
  List<SourceEdit> _filterOverlappingEdits(List<SourceEdit> sortedEdits) {
    final result = <SourceEdit>[];
    int? lastStart;

    for (final edit in sortedEdits) {
      final editEnd = edit.offset + edit.length;
      if (lastStart != null && editEnd > lastStart) {
        // Overlap detected, skip to avoid corruption
        continue;
      }
      result.add(edit);
      lastStart = edit.offset;
    }

    return result;
  }

  /// Inserts the import for localization_helper.dart if not already imported.
  String _ensureImport(
    String content, {
    required String filePath,
    required bool isPartOf,
    required String? partOfUri,
    required String? partOfLibrary,
    required bool hasHelperImport,
    required int? lastImportEnd,
    required int? lastDirectiveEnd,
  }) {
    if (isPartOf) {
      _injectImportIntoParentLibrary(
        filePath,
        partOfUri: partOfUri,
        partOfLibrary: partOfLibrary,
      );
      return content;
    }

    if (hasHelperImport || content.contains('localization_helper.dart')) {
      return content;
    }

    final importStatement = _determineHelperImport(filePath);

    if (lastImportEnd != null) {
      final lineBreakIndex = content.indexOf('\n', lastImportEnd);
      final insertionOffset =
          lineBreakIndex != -1 ? lineBreakIndex + 1 : lastImportEnd;

      return content.substring(0, insertionOffset) +
          '$importStatement\n' +
          content.substring(insertionOffset);
    }

    if (lastDirectiveEnd != null) {
      final lineBreakIndex = content.indexOf('\n', lastDirectiveEnd);
      final insertionOffset =
          lineBreakIndex != -1 ? lineBreakIndex + 1 : lastDirectiveEnd;
      return content.substring(0, insertionOffset) +
          '\n$importStatement\n' +
          content.substring(insertionOffset);
    }

    return '$importStatement\n\n$content';
  }

  void _injectImportIntoParentLibrary(
    String partFilePath, {
    required String? partOfUri,
    required String? partOfLibrary,
  }) {
    String? parentPath;
    if (partOfUri != null) {
      parentPath = p.normalize(p.join(p.dirname(partFilePath), partOfUri));
    } else if (partOfLibrary != null) {
      final dir = Directory(p.dirname(partFilePath));
      if (dir.existsSync()) {
        for (final entity in dir.listSync()) {
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              entity.path != partFilePath) {
            final text = entity.readAsStringSync();
            if (text.contains('library $partOfLibrary')) {
              parentPath = entity.path;
              break;
            }
          }
        }
      }
    }

    if (parentPath == null) return;
    final parentFile = File(parentPath);
    if (!parentFile.existsSync()) return;

    final parentContent = parentFile.readAsStringSync();
    if (parentContent.contains('localization_helper.dart')) return;

    final parentParsed = parseString(
      content: parentContent,
      path: parentPath,
      throwIfDiagnostics: false,
    );
    final importStatement = _determineHelperImport(parentPath);

    final lastImport = parentParsed.unit.directives
        .whereType<ImportDirective>()
        .fold<ImportDirective?>(null, (prev, elem) => elem);

    String newParentContent;
    if (lastImport != null) {
      final endOfImport = lastImport.end;
      final lineBreakIndex = parentContent.indexOf('\n', endOfImport);
      final insertionOffset =
          lineBreakIndex != -1 ? lineBreakIndex + 1 : endOfImport;
      newParentContent = parentContent.substring(0, insertionOffset) +
          '$importStatement\n' +
          parentContent.substring(insertionOffset);
    } else {
      final lastDirective = parentParsed.unit.directives.isNotEmpty
          ? parentParsed.unit.directives.last
          : null;
      if (lastDirective != null) {
        final end = lastDirective.end;
        final lineBreakIndex = parentContent.indexOf('\n', end);
        final insertionOffset = lineBreakIndex != -1 ? lineBreakIndex + 1 : end;
        newParentContent = parentContent.substring(0, insertionOffset) +
            '\n$importStatement\n' +
            parentContent.substring(insertionOffset);
      } else {
        newParentContent = '$importStatement\n\n$parentContent';
      }
    }

    parentFile.writeAsStringSync(newParentContent);
  }

  /// Determines the correct import statement for localization_helper.dart
  /// by inspecting actual directory structure under lib/.
  String _determineHelperImport(String filePath) {
    final libDir = _findLibDirectory(filePath);
    if (libDir != null) {
      final relativePath = _findHelperPath(libDir);
      if (relativePath != null) {
        return "import 'package:$packageName/$relativePath';";
      }
    }
    return "import 'package:$packageName/core/localization/localization_helper.dart';";
  }

  Directory? _findLibDirectory(String filePath) {
    Directory? current = File(filePath).parent;
    while (current != null) {
      if (p.basename(current.path) == 'lib') {
        return current;
      }
      final pubspec = File(p.join(current.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final lib = Directory(p.join(current.path, 'lib'));
        if (lib.existsSync()) return lib;
      }
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    return null;
  }

  String? _findHelperPath(Directory libDir) {
    const commonRelativePaths = [
      'core/localization/localization_helper.dart',
      'localization/localization_helper.dart',
      'core/localization_helper.dart',
      'utils/localization_helper.dart',
      'localization_helper.dart',
    ];

    for (final rel in commonRelativePaths) {
      final file = File(p.join(libDir.path, rel));
      if (file.existsSync()) {
        return rel.replaceAll(r'\', '/');
      }
    }

    try {
      for (final entity
          in libDir.listSync(recursive: true, followLinks: false)) {
        if (entity is File &&
            p.basename(entity.path) == 'localization_helper.dart') {
          return p
              .relative(entity.path, from: libDir.path)
              .replaceAll(r'\', '/');
        }
      }
    } catch (_) {}

    return null;
  }
}
