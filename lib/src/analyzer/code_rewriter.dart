import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import '../generator/arb_manager.dart';
import 'ast_visitor.dart';

/// Result of rewriting a single Dart file.
class RewriteResult {
  final String path;
  final bool modified;
  final String newContent;
  final int stringsExtracted;
  final int constsRemoved;

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
  final ArbManager arbManager;
  final String packageName;

  CodeRewriter({
    required this.arbManager,
    required this.packageName,
  });

  /// Rewrites the given [source] code for file at [filePath].
  RewriteResult rewrite(String source, {required String filePath}) {
    // Never rewrite the localization helper itself
    final normalizedPath = filePath.replaceAll(r'\', '/');
    if (normalizedPath.endsWith('core/localization_helper.dart')) {
      return RewriteResult(
        path: filePath,
        modified: false,
        newContent: source,
      );
    }

    final parseResult = parseString(
      content: source,
      path: filePath,
      throwIfDiagnostics: false,
    );

    final visitor = LocalizationAstVisitor(
      keyGenerator: arbManager.keyGenerator,
    );
    parseResult.unit.accept(visitor);

    if (visitor.candidates.isEmpty) {
      return RewriteResult(
        path: filePath,
        modified: false,
        newContent: source,
      );
    }

    final edits = <SourceEdit>[];
    var extractedCount = 0;

    for (final candidate in visitor.candidates) {
      final key = arbManager.getOrAdd(
        candidate.rawValue,
        keyText: candidate.reconstructedText,
        placeholders: candidate.placeholders,
      );
      if (key != null) {
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

    if (extractedCount == 0) {
      return RewriteResult(
        path: filePath,
        modified: false,
        newContent: source,
      );
    }

    // Add ancestor const removals
    edits.addAll(visitor.constRemovals);

    // Sort edits bottom-to-top (descending by offset)
    edits.sort();

    // Deduplicate any overlapping or duplicate edits
    final safeEdits = _filterOverlappingEdits(edits);

    // Apply edits bottom-to-top
    var currentContent = source;
    for (final edit in safeEdits) {
      final before = currentContent.substring(0, edit.offset);
      final after = currentContent.substring(edit.offset + edit.length);
      currentContent = '$before${edit.replacement}$after';
    }

    // Ensure localization_helper import is present
    currentContent = _ensureImport(
      currentContent,
      filePath: filePath,
      unit: parseResult.unit,
    );

    return RewriteResult(
      path: filePath,
      modified: true,
      newContent: currentContent,
      stringsExtracted: extractedCount,
      constsRemoved: visitor.constRemovals.length,
    );
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
    required CompilationUnit unit,
  }) {
    final helperImportTarget = 'localization_helper.dart';
    if (content.contains(helperImportTarget)) {
      return content;
    }

    final importStatement =
        "import 'package:$packageName/core/localization_helper.dart';";

    // Check if there are existing import directives
    final lastImport = unit.directives
        .whereType<ImportDirective>()
        .fold<ImportDirective?>(null, (prev, elem) => elem);

    if (lastImport != null) {
      // Find the end of the line containing the last import
      final endOfImport = lastImport.end;
      final lineBreakIndex = content.indexOf('\n', endOfImport);
      final insertionOffset =
          lineBreakIndex != -1 ? lineBreakIndex + 1 : endOfImport;

      return content.substring(0, insertionOffset) +
          '$importStatement\n' +
          content.substring(insertionOffset);
    }

    // If no imports exist, place after directives (like library) or at top
    final lastDirective = unit.directives.isNotEmpty ? unit.directives.last : null;
    if (lastDirective != null) {
      final end = lastDirective.end;
      final lineBreakIndex = content.indexOf('\n', end);
      final insertionOffset = lineBreakIndex != -1 ? lineBreakIndex + 1 : end;
      return content.substring(0, insertionOffset) +
          '\n$importStatement\n' +
          content.substring(insertionOffset);
    }

    // Default to the top of the file
    return '$importStatement\n\n$content';
  }
}
