/// Implements a 7-step key generation algorithm that converts hardcoded UI
/// strings into idiomatic, camelCase ARB keys.
class KeyGenerator {
  const KeyGenerator();

  static const Set<String> _dartKeywords = {
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
    'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
    'external', 'factory', 'false', 'final', 'finally', 'for', 'function',
    'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
    'late', 'library', 'mixin', 'native', 'new', 'null', 'of', 'on',
    'operator', 'part', 'required', 'rethrow', 'return', 'sealed', 'set',
    'show', 'static', 'super', 'switch', 'sync', 'this', 'throw', 'true',
    'try', 'typedef', 'var', 'void', 'when', 'while', 'with', 'yield',
  };

  static const Set<String> _prunedWords = {
    'been', 'is', 'are', 'was', 'were', 'being', 'have', 'had', 'the',
    'a', 'an', 'temporarily', 'permanently', 'currently', 'immediately',
  };

  /// Generates a valid ARB key from raw source string [rawText].
  /// Returns `null` if the string should be ignored (e.g. pure numbers, paths, URLs, symbols).
  ///
  /// [existingKeys] contains keys already present in ARB.
  /// [reverseMap] maps exact string values to their previously assigned keys.
  String? generateKey(
    String rawText, {
    Set<String>? existingKeys,
    Map<String, String>? reverseMap,
  }) {
    // Check if this exact text has already been assigned a key
    if (reverseMap != null && reverseMap.containsKey(rawText)) {
      return reverseMap[rawText];
    }

    // Step 1: Validation and Filtering
    if (shouldIgnore(rawText)) {
      return null;
    }

    // Step 2: Tokenization & Sanitization
    final rawTokens = _tokenize(rawText);
    if (rawTokens.isEmpty) {
      return null;
    }

    // Step 3: Reposition leading digits
    final repositionedTokens = _repositionLeadingDigits(rawTokens);

    // Step 4: Prune filler words & adverbs
    final prunedPool = _filterPrunedWords(repositionedTokens);
    if (prunedPool.isEmpty) {
      return null;
    }

    // Step 5: Candidate key building with 2nd/3rd-last word collision fallback
    final candidateKeys = _buildCandidateKeys(prunedPool);
    for (final candidate in candidateKeys) {
      final resolved = _resolveReservedKeywords(candidate);
      if (existingKeys == null || !existingKeys.contains(resolved)) {
        return resolved;
      }
    }

    // Step 7: Fall back to numeric suffix disambiguation on primary candidate
    final primaryCandidate = _resolveReservedKeywords(candidateKeys.first);
    return _disambiguateKey(primaryCandidate, existingKeys);
  }

  /// Step 1: Detects strings that should never be localized.
  bool shouldIgnore(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;

    // Email patterns with no spaces (e.g. example@domain.com)
    if (trimmed.contains('@') && !trimmed.contains(' ')) {
      return true;
    }

    // Must contain at least one alphabetic letter
    // Strings with only digits, symbols, currency, punctuation (e.g. "2026", "100%", "+91-9876543210", "₹500", "---") are ignored!
    if (!RegExp(r'[\p{Letter}]', unicode: true).hasMatch(trimmed)) {
      return true;
    }

    // URLs and URIs
    if (RegExp(r'^(https?|ftp|file|mailto|ws|wss):', caseSensitive: false)
        .hasMatch(trimmed)) {
      return true;
    }

    // Asset paths, file paths, and common extensions
    if (RegExp(r'^(assets/|packages/|lib/|[a-zA-Z0-9_\-]+/[a-zA-Z0-9_\-\.\/]+)')
        .hasMatch(trimmed)) {
      return true;
    }
    if (RegExp(r'\.(png|jpg|jpeg|gif|svg|webp|json|arb|dart|ttf|otf|mp3|mp4|ico)$',
            caseSensitive: false)
        .hasMatch(trimmed)) {
      return true;
    }

    // Route paths (e.g., "/login", "/home", "/")
    if (RegExp(r'^/[a-zA-Z0-9_\-\/]*$').hasMatch(trimmed)) {
      return true;
    }

    // Single punctuation / separator
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(trimmed)) {
      return true;
    }

    // Date / time formatting patterns
    if (RegExp(r'^(yyyy|MM|dd|HH|mm|ss)[\/\-:\. ]*(yyyy|MM|dd|HH|mm|ss)*$')
        .hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  static const Map<String, String> _cyrillicMap = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
    'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo',
    'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M',
    'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
    'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch',
    'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
  };

  /// Step 2: Split string into words and numbers, removing punctuation, transliterating Cyrillic, and splitting camelCase.
  List<String> _tokenize(String text) {
    // Normalize contractions and possessives: "It's" -> "Its", "user's" -> "user"
    final normalized = text
        .replaceAll(RegExp(r"\bIt['’]s\b", caseSensitive: false), 'Its')
        .replaceAll(RegExp(r"['’]s\b"), '')
        .replaceAll(RegExp(r"['’]"), '');

    // Transliterate Cyrillic to Latin for valid Dart identifier generation
    final buffer = StringBuffer();
    for (final char in normalized.split('')) {
      buffer.write(_cyrillicMap[char] ?? char);
    }
    final transliterated = buffer.toString();

    // Split camelCase boundaries (e.g. userName -> user Name, totalAmount -> total Amount)
    final splitCamel = transliterated.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );

    // Replace non-alphanumeric characters with spaces
    final cleaned = splitCamel.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ').trim();
    if (cleaned.isEmpty) {
      // Deterministic fallback for non-Latin scripts (e.g. Chinese, Bengali, Hindi, Arabic)
      final hash = text.hashCode.abs() % 100000;
      return ['msg$hash'];
    }

    final tokens = <String>[];
    for (final part in cleaned.split(RegExp(r'\s+'))) {
      if (part.isNotEmpty) {
        tokens.add(part);
      }
    }
    return tokens;
  }

  /// Step 3: If tokens start with digits (e.g., ["24", "7", "Customer", "Support", "Available"]),
  /// find the first token starting with [a-zA-Z], remove it, and insert it at index 0.
  /// (yielding ["Customer", "24", "7", "Support", "Available"]).
  List<String> _repositionLeadingDigits(List<String> tokens) {
    if (tokens.isEmpty) return tokens;

    final result = List<String>.from(tokens);
    if (RegExp(r'^\d').hasMatch(result.first)) {
      final firstWordIdx = result.indexWhere(
        (t) => RegExp(r'^\p{Letter}', unicode: true).hasMatch(t),
      );

      if (firstWordIdx != -1) {
        final firstWord = result.removeAt(firstWordIdx);
        result.insert(0, firstWord);
      } else {
        result[0] = 'text${result[0]}';
      }
    }
    return result;
  }

  /// Step 4: Filter out noisy stopwords and adverbs ending in -ly.
  List<String> _filterPrunedWords(List<String> tokens) {
    final filtered = <String>[];

    for (final token in tokens) {
      final lower = token.toLowerCase();
      if (_prunedWords.contains(lower)) {
        continue;
      }
      if (lower.length > 4 && lower.endsWith('ly')) {
        continue;
      }
      filtered.add(token);
    }

    return filtered.isNotEmpty ? filtered : tokens;
  }

  /// Step 5: Builds candidates. If pool > 4 words:
  /// Primary candidate: first 3 + last word.
  /// Fallback 1: first 3 + 2nd-last word.
  /// Fallback 2: first 3 + 3rd-last word.
  List<String> _buildCandidateKeys(List<String> pool) {
    if (pool.length <= 4) {
      return [_toCamelCase(pool)];
    }

    final candidates = <String>[];
    final first3 = [pool[0], pool[1], pool[2]];

    // 1. Primary candidate: first 3 + last word
    candidates.add(_toCamelCase([...first3, pool.last]));

    // 2. Fallback candidate: first 3 + 2nd-last word
    if (pool.length > 4) {
      candidates.add(_toCamelCase([...first3, pool[pool.length - 2]]));
    }

    // 3. Fallback candidate: first 3 + 3rd-last word
    if (pool.length > 5) {
      candidates.add(_toCamelCase([...first3, pool[pool.length - 3]]));
    }

    return candidates;
  }

  /// Converts list of tokens into lowerCamelCase.
  String _toCamelCase(List<String> tokens) {
    final buffer = StringBuffer();
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (i == 0) {
        buffer.write(token.toLowerCase());
      } else {
        final lower = token.toLowerCase();
        buffer.write(lower[0].toUpperCase());
        if (lower.length > 1) {
          buffer.write(lower.substring(1));
        }
      }
    }
    return buffer.toString();
  }

  /// Step 6: Suffix with 'Text' if the key matches a Dart reserved keyword or starts with digit.
  String _resolveReservedKeywords(String key) {
    if (_dartKeywords.contains(key.toLowerCase())) {
      return '${key}Text';
    }
    if (RegExp(r'^\d').hasMatch(key)) {
      return 'text$key';
    }
    return key;
  }

  /// Step 7: Disambiguate key name if an existing entry already uses this identifier.
  String _disambiguateKey(String key, Set<String>? existingKeys) {
    if (existingKeys == null || !existingKeys.contains(key)) {
      return key;
    }

    var suffix = 2;
    while (existingKeys.contains('$key$suffix')) {
      suffix++;
    }
    return '$key$suffix';
  }
}
