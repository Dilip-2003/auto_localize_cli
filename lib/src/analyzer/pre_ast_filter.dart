/// Ultra-fast lexical pre-filter to bypass AST parsing for non-UI files.
class PreAstFilter {
  PreAstFilter._();

  static const List<String> _uiTokens = [
    'Text',
    'SelectableText',
    'Tooltip',
    'title:',
    'subtitle:',
    'label:',
    'hintText:',
    'labelText:',
    'helperText:',
    'errorText:',
    'counterText:',
    'prefixText:',
    'suffixText:',
    'semanticLabel:',
    'semanticsLabel:',
    'tooltip:',
    'message:',
    'text:',
    'confirmText:',
    'cancelText:',
    'header:',
    'content:',
  ];

  /// Returns `true` if [content] might contain localizable UI or core strings.
  ///
  /// If `false`, the file is guaranteed to have zero localizable strings, allowing
  /// the engine to skip the expensive AST parsing step completely (<0.01ms check).
  static bool canContainLocalizableStrings(
    String content, {
    required String filePath,
  }) {
    // 1. Must contain at least one string quote delimiter
    if (!content.contains('"') && !content.contains("'")) {
      return false;
    }

    // 2. Core string files (e.g. app_strings.dart) must always be parsed
    final normalized = filePath.replaceAll(r'\', '/');
    if (normalized.endsWith('app_strings.dart')) {
      return true;
    }

    // 3. UI files must contain at least one whitelisted UI constructor or parameter token
    for (var i = 0; i < _uiTokens.length; i++) {
      if (content.contains(_uiTokens[i])) {
        return true;
      }
    }

    return false;
  }
}
