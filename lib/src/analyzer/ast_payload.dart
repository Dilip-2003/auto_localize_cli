import 'dart:isolate';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'ast_visitor.dart';

/// Serializable input payload for AST parsing worker isolates.
class FileToParse {
  /// The absolute path to the file.
  final String filePath;

  /// The relative path from the project root.
  final String relativePath;

  /// The file source code content.
  final String source;

  /// File modification timestamp in microseconds.
  final int statModifiedMicros;

  /// File size in bytes.
  final int statSize;

  /// Creates a [FileToParse].
  const FileToParse({
    required this.filePath,
    required this.relativePath,
    required this.source,
    required this.statModifiedMicros,
    required this.statSize,
  });
}

/// Serializable extracted candidate metadata.
class ParsedCandidate {
  /// Start character offset in source.
  final int offset;

  /// Length in characters.
  final int length;

  /// ARB template string, e.g. "Hello {userName}".
  final String rawValue;

  /// Normalized text used for key generation, e.g. "Hello userName".
  final String reconstructedText;

  /// Extracted placeholder identifiers.
  final List<String> placeholders;

  /// Dart arguments to pass to the generated getter.
  final List<String> arguments;

  /// Custom getter name if converting a static const field.
  final String? customFieldGetterName;

  /// Start offset of the parent field declaration if applicable.
  final int? fieldOffset;

  /// Length of the parent field declaration if applicable.
  final int? fieldLength;

  /// Creates a [ParsedCandidate].
  const ParsedCandidate({
    required this.offset,
    required this.length,
    required this.rawValue,
    required this.reconstructedText,
    this.placeholders = const [],
    this.arguments = const [],
    this.customFieldGetterName,
    this.fieldOffset,
    this.fieldLength,
  });
}

/// Serializable const removal modification.
class ParsedConstRemoval {
  /// Character offset in source.
  final int offset;

  /// Character length to replace.
  final int length;

  /// Replacement string.
  final String replacement;

  /// Creates a [ParsedConstRemoval].
  const ParsedConstRemoval({
    required this.offset,
    required this.length,
    required this.replacement,
  });
}

/// Output payload from AST parsing worker isolates.
class ParsedFilePayload {
  /// Absolute file path.
  final String filePath;

  /// Relative file path.
  final String relativePath;

  /// Original file source code.
  final String source;

  /// Modification timestamp in microseconds.
  final int statModifiedMicros;

  /// File size in bytes.
  final int statSize;

  /// All identified string candidates.
  final List<ParsedCandidate> candidates;

  /// All identified const keyword removals.
  final List<ParsedConstRemoval> constRemovals;

  /// Whether this file contains a `part of` directive.
  final bool isPartOf;

  /// URI string of the parent library if specified.
  final String? partOfUri;

  /// Library name of the parent library if specified.
  final String? partOfLibrary;

  /// Whether the file already contains `localization_helper.dart`.
  final bool hasHelperImport;

  /// Character end position of the last import directive.
  final int? lastImportEnd;

  /// Character end position of the last directive.
  final int? lastDirectiveEnd;

  /// Creates a [ParsedFilePayload].
  const ParsedFilePayload({
    required this.filePath,
    required this.relativePath,
    required this.source,
    required this.statModifiedMicros,
    required this.statSize,
    required this.candidates,
    required this.constRemovals,
    required this.isPartOf,
    this.partOfUri,
    this.partOfLibrary,
    required this.hasHelperImport,
    this.lastImportEnd,
    this.lastDirectiveEnd,
  });
}

/// Top-level worker function executing in worker isolates.
List<ParsedFilePayload> parseFilesWorker(List<FileToParse> files) {
  final results = <ParsedFilePayload>[];

  for (final file in files) {
    final parseResult = parseString(
      content: file.source,
      path: file.filePath,
      throwIfDiagnostics: false,
    );

    final visitor = LocalizationAstVisitor();
    parseResult.unit.accept(visitor);

    final partOf =
        parseResult.unit.directives.whereType<PartOfDirective>().firstOrNull;
    final lastImport = parseResult.unit.directives
        .whereType<ImportDirective>()
        .fold<ImportDirective?>(null, (prev, elem) => elem);
    final lastDirective = parseResult.unit.directives.isNotEmpty
        ? parseResult.unit.directives.last
        : null;

    final parsedCandidates = visitor.candidates
        .map(
          (c) => ParsedCandidate(
            offset: c.offset,
            length: c.length,
            rawValue: c.rawValue,
            reconstructedText: c.reconstructedText,
            placeholders: c.placeholders,
            arguments: c.arguments,
            customFieldGetterName: c.customFieldGetterName,
            fieldOffset: c.fieldOffset,
            fieldLength: c.fieldLength,
          ),
        )
        .toList();

    final parsedConsts = visitor.constRemovals
        .map(
          (r) => ParsedConstRemoval(
            offset: r.offset,
            length: r.length,
            replacement: r.replacement,
          ),
        )
        .toList();

    results.add(
      ParsedFilePayload(
        filePath: file.filePath,
        relativePath: file.relativePath,
        source: file.source,
        statModifiedMicros: file.statModifiedMicros,
        statSize: file.statSize,
        candidates: parsedCandidates,
        constRemovals: parsedConsts,
        isPartOf: partOf != null,
        partOfUri: partOf?.uri?.stringValue,
        partOfLibrary: partOf?.libraryName?.name,
        hasHelperImport: file.source.contains('localization_helper.dart'),
        lastImportEnd: lastImport?.end,
        lastDirectiveEnd: lastDirective?.end,
      ),
    );
  }

  return results;
}

/// Parses a batch of files, distributing work across [workers] isolates if batch size permits.
Future<List<ParsedFilePayload>> parseCandidateBatch(
  List<FileToParse> batch, {
  required int workers,
}) async {
  if (batch.isEmpty) return [];

  if (workers <= 1 || batch.length < 4) {
    return parseFilesWorker(batch);
  }

  final effectiveWorkers = workers.clamp(1, batch.length);
  final chunkSize = (batch.length / effectiveWorkers).ceil();
  final futures = <Future<List<ParsedFilePayload>>>[];

  for (var i = 0; i < batch.length; i += chunkSize) {
    final end = (i + chunkSize < batch.length) ? i + chunkSize : batch.length;
    final subBatch = batch.sublist(i, end);
    futures.add(Isolate.run(() => parseFilesWorker(subBatch)));
  }

  final nested = await Future.wait(futures);
  return nested.expand((list) => list).toList();
}
