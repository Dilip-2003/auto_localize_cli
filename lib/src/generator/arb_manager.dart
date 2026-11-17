import 'dart:convert';
import 'dart:io';
import 'key_generator.dart';

/// Manages loading, reading, writing, and deduplicating strings in ARB files.
class ArbManager {
  /// The target ARB file on disk.
  final File arbFile;

  /// Key generator instance for deriving identifiers.
  final KeyGenerator keyGenerator;

  final Map<String, dynamic> _data = <String, dynamic>{};
  final Map<String, String> _reverseMap = <String, String>{};

  /// Creates a new [ArbManager] for [arbFile] with optional [keyGenerator].
  ArbManager({
    required this.arbFile,
    this.keyGenerator = const KeyGenerator(),
  });

  /// Map of string value to generated key.
  Map<String, String> get reverseMap => Map.unmodifiable(_reverseMap);

  /// Current keys in ARB (excluding metadata starting with '@').
  Set<String> get existingKeys =>
      _data.keys.where((k) => !k.startsWith('@')).toSet();

  /// Loads the ARB file from disk. If the file doesn't exist, initializes it.
  Future<void> load() async {
    _data.clear();
    _reverseMap.clear();

    if (await arbFile.exists()) {
      final content = await arbFile.readAsString();
      if (content.trim().isNotEmpty) {
        try {
          final decoded = json.decode(content);
          if (decoded is Map<String, dynamic>) {
            _data.addAll(decoded);
          } else {
            throw const FormatException('ARB file content must be a JSON object.');
          }
        } catch (e) {
          stderr.writeln(
              'Error: Failed to parse ARB JSON at ${arbFile.path}: $e');
          stderr.writeln(
              'Extraction aborted to prevent permanent data loss. Please fix JSON syntax errors.');
          rethrow;
        }
      }
    }

    if (!_data.containsKey('@@locale')) {
      _data['@@locale'] = 'en';
    }

    // Build reverse map for non-metadata string entries
    for (final entry in _data.entries) {
      if (!entry.key.startsWith('@') && entry.value is String) {
        _reverseMap[entry.value as String] = entry.key;
      }
    }
  }

  /// Adds a string to ARB if not already present, or returns its existing key.
  /// If [placeholders] is provided, adds `@key` metadata with placeholder definitions.
  /// Returns `null` if the string was rejected by [keyGenerator].
  String? getOrAdd(
    String stringValue, {
    String? keyText,
    List<String> placeholders = const [],
  }) {
    if (_reverseMap.containsKey(stringValue)) {
      return _reverseMap[stringValue];
    }

    final key = keyGenerator.generateKey(
      keyText ?? stringValue,
      existingKeys: existingKeys,
      reverseMap: _reverseMap,
    );

    if (key == null) {
      return null;
    }

    // Escape literal unparameterized braces in ARB string to avoid ICU syntax errors in gen-l10n
    var storedValue = stringValue;
    if (placeholders.isEmpty && storedValue.contains('{')) {
      storedValue = storedValue.replaceAll('{', "'{'").replaceAll('}', "'}'");
    }

    _data[key] = storedValue;
    _reverseMap[stringValue] = key;

    if (placeholders.isNotEmpty) {
      final placeholdersMap = <String, dynamic>{};
      for (final p in placeholders) {
        placeholdersMap[p] = <String, dynamic>{};
      }
      _data['@$key'] = {
        'placeholders': placeholdersMap,
      };
    }

    return key;
  }

  /// Saves the current entries to the ARB file formatted with 2 spaces indentation.
  Future<void> save() async {
    await arbFile.parent.create(recursive: true);

    // Structure map: @@locale first, followed by keys and their optional metadata
    final orderedMap = <String, dynamic>{};

    if (_data.containsKey('@@locale')) {
      orderedMap['@@locale'] = _data['@@locale'];
    }

    final regularKeys = _data.keys.where((k) => !k.startsWith('@')).toList()
      ..sort();

    for (final key in regularKeys) {
      orderedMap[key] = _data[key];
      final metaKey = '@$key';
      if (_data.containsKey(metaKey)) {
        orderedMap[metaKey] = _data[metaKey];
      }
    }

    // Include any other metadata keys (e.g. @@context)
    for (final key in _data.keys) {
      if (key.startsWith('@@') && key != '@@locale') {
        orderedMap[key] = _data[key];
      }
    }

    final encoder = const JsonEncoder.withIndent('  ');
    final formattedJson = '${encoder.convert(orderedMap)}\n';
    await arbFile.writeAsString(formattedJson);
  }
}
