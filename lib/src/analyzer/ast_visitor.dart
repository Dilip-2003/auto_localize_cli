import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import '../generator/key_generator.dart';

/// Represents a single text modification (either a string replacement or const removal).
class SourceEdit implements Comparable<SourceEdit> {
  /// Start character offset in the source file.
  final int offset;

  /// Length of characters to replace.
  final int length;

  /// Replacement string content.
  final String replacement;

  /// Creates a new [SourceEdit] modification.
  const SourceEdit({
    required this.offset,
    required this.length,
    required this.replacement,
  });

  @override
  int compareTo(SourceEdit other) {
    // Sort descending by offset: bottom-to-top
    return other.offset.compareTo(offset);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceEdit &&
          runtimeType == other.runtimeType &&
          offset == other.offset &&
          length == other.length &&
          replacement == other.replacement;

  @override
  int get hashCode => Object.hash(offset, length, replacement);

  @override
  String toString() =>
      'SourceEdit(offset: $offset, len: $length, rep: "$replacement")';
}

/// Information about an extracted string literal candidate.
class ExtractionCandidate {
  /// Start offset of the candidate literal.
  final int offset;

  /// Length of the candidate literal in characters.
  final int length;

  /// ARB template string, e.g. "Hello {userName}".
  final String rawValue;

  /// Normalized text used for key generation, e.g. "Hello userName".
  final String reconstructedText;

  /// Extracted placeholder identifiers, e.g. ["userName"].
  final List<String> placeholders;

  /// Raw Dart argument expressions to pass, e.g. ["user.name"].
  final List<String> arguments;

  /// Custom getter name if converting a static const field.
  final String? customFieldGetterName;

  /// Start offset of the parent field declaration if applicable.
  final int? fieldOffset;

  /// Length of the parent field declaration if applicable.
  final int? fieldLength;

  /// Creates a new [ExtractionCandidate].
  const ExtractionCandidate({
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

/// AST Visitor that finds UI & core strings and tracks ancestor const tokens.
class LocalizationAstVisitor extends RecursiveAstVisitor<void> {
  /// Key generator instance for filter and validation rules.
  final KeyGenerator keyGenerator;

  /// All identified extraction candidates in this compilation unit.
  final List<ExtractionCandidate> candidates = [];

  final Set<int> _seenConstOffsets = {};

  /// All ancestor const tokens marked for deletion.
  final List<SourceEdit> constRemovals = [];

  static const Set<String> _ignoredInvocations = {
    'print',
    'debugPrint',
    'log',
    'RegExp',
    'Key',
    'ValueKey',
    'Locale',
    'AssetImage',
    'NetworkImage',
    'ExactAssetImage',
    'pushNamed',
    'pushReplacementNamed',
    'MethodChannel',
    'EventChannel',
    'ThemeData',
    'Duration',
  };

  static const Set<String> _uiNamedParams = {
    'labelText',
    'hintText',
    'helperText',
    'errorText',
    'prefixText',
    'suffixText',
    'counterText',
    'tooltip',
    'semanticsLabel',
    'title',
    'subtitle',
    'message',
    'text',
    'label',
    'header',
    'content',
    'confirmText',
    'cancelText',
    'buttonText',
    'action',
    'prompt',
  };

  LocalizationAstVisitor({
    this.keyGenerator = const KeyGenerator(),
  });

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // If part of AdjacentStrings, let visitAdjacentStrings handle the whole string
    if (node.parent is AdjacentStrings) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    final value = node.stringValue;
    if (value == null ||
        !RegExp(r'[\p{Letter}]', unicode: true).hasMatch(value) ||
        keyGenerator.shouldIgnore(value)) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    if (_isIgnoredContext(node)) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    // Check Case 3: static const String field in AppStrings -> convert to static getter
    final fieldCandidate = _checkConstFieldCandidate(node, value);
    if (fieldCandidate != null) {
      candidates.add(fieldCandidate);
      return;
    }

    if (_isExtractableContext(node)) {
      candidates.add(
        ExtractionCandidate(
          offset: node.offset,
          length: node.length,
          rawValue: value,
          reconstructedText: value,
        ),
      );

      _trackAncestorConsts(node);
    }

    super.visitSimpleStringLiteral(node);
  }

  /// Checks if node is inside a static const String field declaration in a Strings class.
  ExtractionCandidate? _checkConstFieldCandidate(
    SimpleStringLiteral node,
    String value,
  ) {
    final parent = node.parent;
    if (parent is! VariableDeclaration) return null;
    final varList = parent.parent;
    if (varList is! VariableDeclarationList) return null;
    final fieldDecl = varList.parent;
    if (fieldDecl is! FieldDeclaration) return null;
    final parentClass = fieldDecl.parent;
    if (parentClass is! ClassDeclaration) return null;

    final className = parentClass.name.lexeme;
    if (!className.contains('Strings') &&
        !className.contains('Errors') &&
        !className.contains('Messages')) {
      return null;
    }

    if (varList.isConst) {
      final varName = parent.name.lexeme;
      final start = fieldDecl.firstTokenAfterCommentAndMetadata.offset;
      final length = fieldDecl.end - start;
      return ExtractionCandidate(
        offset: node.offset,
        length: node.length,
        rawValue: value,
        reconstructedText: value,
        customFieldGetterName: varName,
        fieldOffset: start,
        fieldLength: length,
      );
    }

    return null;
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final value = node.stringValue;
    if (value == null ||
        !RegExp(r'[\p{Letter}]', unicode: true).hasMatch(value) ||
        keyGenerator.shouldIgnore(value)) {
      super.visitAdjacentStrings(node);
      return;
    }

    if (_isIgnoredContext(node)) {
      super.visitAdjacentStrings(node);
      return;
    }

    if (_isExtractableContext(node)) {
      candidates.add(
        ExtractionCandidate(
          offset: node.offset,
          length: node.length,
          rawValue: value,
          reconstructedText: value,
        ),
      );

      _trackAncestorConsts(node);
    }

    super.visitAdjacentStrings(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (_isIgnoredContext(node)) {
      super.visitStringInterpolation(node);
      return;
    }

    if (!_isExtractableContext(node)) {
      super.visitStringInterpolation(node);
      return;
    }

    // 1. Gather all static InterpolationString text parts
    final staticBuffer = StringBuffer();
    for (final element in node.elements) {
      if (element is InterpolationString) {
        staticBuffer.write(element.value);
      }
    }
    final staticText = staticBuffer.toString();

    // Ignore Rule: If static parts contain NO alphabetic characters, skip!
    if (!RegExp(r'[\p{Letter}]', unicode: true).hasMatch(staticText)) {
      super.visitStringInterpolation(node);
      return;
    }

    // Skip asset paths, URLs, etc.
    if (keyGenerator.shouldIgnore(staticText)) {
      super.visitStringInterpolation(node);
      return;
    }

    // 2. Build ARB template and extract unique placeholders & expressions
    final arbTemplateBuffer = StringBuffer();
    final reconstructedBuffer = StringBuffer();
    final exprToPlaceholder = <String, String>{};
    final uniquePlaceholders = <String>[];
    final uniqueArguments = <String>[];
    final usedPlaceholderNames = <String>{};

    var fallbackIndex = 1;

    for (final element in node.elements) {
      if (element is InterpolationString) {
        arbTemplateBuffer.write(element.value);
        reconstructedBuffer.write(element.value);
      } else if (element is InterpolationExpression) {
        final rawExpr = element.expression.toSource().trim();

        String placeholderName;
        if (exprToPlaceholder.containsKey(rawExpr)) {
          // Re-use already assigned placeholder for this identical expression
          placeholderName = exprToPlaceholder[rawExpr]!;
        } else {
          placeholderName = _derivePlaceholderName(
            rawExpr,
            usedPlaceholderNames,
            fallbackIndex,
          );
          if (placeholderName == 'param$fallbackIndex') {
            fallbackIndex++;
          }
          usedPlaceholderNames.add(placeholderName);
          exprToPlaceholder[rawExpr] = placeholderName;
          uniquePlaceholders.add(placeholderName);
          uniqueArguments.add(rawExpr);
        }

        arbTemplateBuffer.write('{$placeholderName}');
        reconstructedBuffer.write(' $placeholderName ');
      }
    }

    final rawTemplate = arbTemplateBuffer.toString();
    final reconstructed = reconstructedBuffer.toString();

    candidates.add(
      ExtractionCandidate(
        offset: node.offset,
        length: node.length,
        rawValue: rawTemplate,
        reconstructedText: reconstructed,
        placeholders: uniquePlaceholders,
        arguments: uniqueArguments,
      ),
    );

    _trackAncestorConsts(node);

    super.visitStringInterpolation(node);
  }

  /// Derives a clean camelCase placeholder identifier from a Dart expression.
  String _derivePlaceholderName(
    String rawExpr,
    Set<String> usedNames,
    int fallbackIndex,
  ) {
    final cleaned = rawExpr.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ').trim();
    final tokens =
        cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    String candidate;
    if (tokens.isEmpty || RegExp(r'^\d').hasMatch(tokens.first)) {
      candidate = 'param$fallbackIndex';
    } else {
      final buffer = StringBuffer();
      for (var i = 0; i < tokens.length; i++) {
        final t = tokens[i];
        if (i == 0) {
          buffer.write(t.substring(0, 1).toLowerCase() + t.substring(1));
        } else {
          buffer.write(t.substring(0, 1).toUpperCase() + t.substring(1));
        }
      }
      candidate = buffer.toString();
    }

    if (candidate.isEmpty || RegExp(r'^\d').hasMatch(candidate)) {
      candidate = 'param$fallbackIndex';
    }

    var result = candidate;
    var suffix = 2;
    while (usedNames.contains(result)) {
      result = '$candidate$suffix';
      suffix++;
    }

    return result;
  }

  /// Checks if node is in an ignored context (directives, annotations, assert, constructor default params, etc.).
  bool _isIgnoredContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is UriBasedDirective ||
          current is Annotation ||
          current is AssertStatement ||
          current is AssertInitializer ||
          current is DefaultFormalParameter ||
          current is ConstructorInitializer ||
          current is Configuration) {
        return true;
      }

      if (current is MethodInvocation) {
        final methodName = current.methodName.name;
        if (_ignoredInvocations.contains(methodName)) {
          return true;
        }
      }

      if (current is InstanceCreationExpression) {
        final typeName = current.constructorName.type.name2.lexeme;
        if (_ignoredInvocations.contains(typeName)) {
          return true;
        }
      }

      current = current.parent;
    }
    return false;
  }

  /// Checks if node is used in a UI widget or string method/getter.
  bool _isExtractableContext(AstNode node) {
    final parent = node.parent;

    // Case 1: Named argument with UI parameter name
    if (parent is NamedExpression) {
      final label = parent.name.label.name;
      if (_uiNamedParams.contains(label)) {
        return true;
      }
    }

    // Case 2: Positional argument in Flutter widget (e.g. Text("Hello"), SelectableText("Hello"))
    if (parent is ArgumentList) {
      final grandParent = parent.parent;
      if (grandParent is InstanceCreationExpression) {
        final typeName = grandParent.constructorName.type.name2.lexeme;
        if (!_ignoredInvocations.contains(typeName)) {
          return true;
        }
      }

      // In unresolved ASTs, constructor calls without 'const' or 'new' parse as MethodInvocation
      if (grandParent is MethodInvocation) {
        final name = grandParent.methodName.name;
        final target = grandParent.target;

        // PascalCase invocations (e.g. Text("..."), SelectableText("..."))
        if (RegExp(r'^[A-Z]').hasMatch(name) &&
            !_ignoredInvocations.contains(name)) {
          return true;
        }

        // Static or named constructor invocations (e.g. Text.rich(...))
        if (target is SimpleIdentifier &&
            RegExp(r'^[A-Z]').hasMatch(target.name) &&
            !_ignoredInvocations.contains(target.name)) {
          return true;
        }
      }
    }

    // Case 3: Inside a getter or method in core string classes
    if (_isInsideStringMethodOrGetter(node)) {
      return true;
    }

    return false;
  }

  /// Checks if node is the expression or return value of a getter or String method.
  bool _isInsideStringMethodOrGetter(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        if (current.isGetter) return true;
        final returnType = current.returnType?.toSource();
        if (returnType == 'String') return true;

        final parentClass = current.parent;
        if (parentClass is ClassDeclaration) {
          final className = parentClass.name.lexeme;
          if (className.contains('Strings') ||
              className.contains('Errors') ||
              className.contains('Messages') ||
              className.contains('Constants')) {
            return true;
          }
        }
      }

      if (current is FunctionDeclaration) {
        if (current.isGetter) return true;
        final returnType = current.returnType?.toSource();
        if (returnType == 'String') return true;
      }

      if (current is VariableDeclaration) {
        final parentList = current.parent;
        if (parentList is VariableDeclarationList) {
          final type = parentList.type?.toSource();
          if (type == 'String') return true;
        }
        final parentClass = current.parent?.parent?.parent;
        if (parentClass is ClassDeclaration) {
          final className = parentClass.name.lexeme;
          if (className.contains('Strings') ||
              className.contains('Errors') ||
              className.contains('Messages')) {
            return true;
          }
        }
      }

      if (current is ClassDeclaration ||
          current is CompilationUnit ||
          current is ExtensionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }

  /// Walks up the AST hierarchy from [node] and records any ancestor `const` tokens.
  void _trackAncestorConsts(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final keyword = current.keyword;
        if (keyword != null && keyword.lexeme == 'const') {
          _recordConstRemoval(keyword);
        }
      } else if (current is TypedLiteral) {
        final keyword = current.constKeyword;
        if (keyword != null && keyword.lexeme == 'const') {
          _recordConstRemoval(keyword);
        }
      }
      current = current.parent;
    }
  }

  /// Registers a `const` token for removal, ensuring each token is only removed once.
  void _recordConstRemoval(Token keyword) {
    if (_seenConstOffsets.contains(keyword.offset)) {
      return;
    }
    _seenConstOffsets.add(keyword.offset);

    final start = keyword.offset;
    final end = keyword.next?.offset ?? keyword.end;

    constRemovals.add(
      SourceEdit(
        offset: start,
        length: end - start,
        replacement: '',
      ),
    );
  }
}
