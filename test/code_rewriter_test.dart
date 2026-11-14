import 'dart:io';
import 'package:auto_localize_cli/src/analyzer/code_rewriter.dart';
import 'package:auto_localize_cli/src/generator/arb_manager.dart';
import 'package:test/test.dart';

void main() {
  group('CodeRewriter', () {
    late Directory tempDir;
    late ArbManager arbManager;
    late CodeRewriter rewriter;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rewriter_test_');
      final arbFile = File('${tempDir.path}/app_en.arb');
      arbManager = ArbManager(arbFile: arbFile);
      await arbManager.load();
      rewriter = CodeRewriter(
        arbManager: arbManager,
        packageName: 'test_app',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rewrites const Text and removes ancestor const', () {
      const source = '''
import 'package:flutter/material.dart';

class MyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text("404 Page Not Found"),
        Text("Continue"),
        Text("2026"),
      ],
    );
  }
}
''';

      final result = rewriter.rewrite(source, filePath: 'lib/main.dart');

      expect(result.modified, isTrue);
      expect(result.stringsExtracted, equals(2)); // 404 Page Not Found & Continue, 2026 is ignored
      expect(result.constsRemoved, equals(1)); // Column's const is removed

      // Verify source changes
      expect(result.newContent, contains('Text(l10n.page404NotFound)'));
      expect(result.newContent, contains('Text(l10n.continueText)'));
      expect(result.newContent, contains('Text("2026")')); // 2026 kept as-is
      expect(result.newContent, isNot(contains('const Column')));
      expect(result.newContent, contains('return Column('));

      // Verify auto-import
      expect(
        result.newContent,
        contains("import 'package:test_app/core/localization_helper.dart';"),
      );

      // Verify ARB entries
      expect(arbManager.existingKeys, contains('page404NotFound'));
      expect(arbManager.existingKeys, contains('continueText'));
      expect(arbManager.existingKeys, isNot(contains('text2026')));
    });

    test('rewrites static String get networkError in core error class', () {
      const source = '''
class AppStrings {
  AppStrings._();

  static String get networkError => "Please check your internet connection";
}
''';

      final result = rewriter.rewrite(source, filePath: 'lib/core/app_strings.dart');

      expect(result.modified, isTrue);
      expect(result.stringsExtracted, equals(1));
      expect(
        result.newContent,
        contains('static String get networkError => l10n.pleaseCheckYourConnection;'),
      );
      expect(
        result.newContent,
        contains("import 'package:test_app/core/localization_helper.dart';"),
      );
      expect(arbManager.existingKeys, contains('pleaseCheckYourConnection'));
    });

    test('rewrites StringInterpolation into parameterized calls and extracts @metadata', () {
      const source = '''
import 'package:flutter/material.dart';

class GreetingView extends StatelessWidget {
  final String userName;
  final dynamic order;
  final String name;
  const GreetingView({super.key, required this.userName, required this.order, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Hello \$userName"),
        Text("Total: ₹\${order.totalAmount}"),
        Text("Hi \$name, welcome \$name"),
        Text("\$userName \$userName"), // No alphabetic text, must be ignored!
        Text("₹\${order.totalAmount}"), // No alphabetic text, must be ignored!
      ],
    );
  }
}
''';

      final result = rewriter.rewrite(source, filePath: 'lib/view.dart');

      expect(result.modified, isTrue);
      expect(result.stringsExtracted, equals(3)); // 3 translatable interpolations

      // Verify parameter calls in Dart code
      expect(result.newContent, contains('Text(l10n.helloUserName(userName))'));
      expect(
        result.newContent,
        contains('Text(l10n.totalOrderTotalAmount(order.totalAmount))'),
      );
      // Deduplicated parameter: name passed only once!
      expect(
        result.newContent,
        contains('Text(l10n.hiNameWelcomeName(name))'),
      );

      // Verify un-localizable interpolations are untouched
      expect(result.newContent, contains(r'Text("$userName $userName")'));
      expect(result.newContent, contains(r'Text("₹${order.totalAmount}")'));

      // Verify ARB entries and metadata
      expect(arbManager.existingKeys, contains('helloUserName'));
      expect(arbManager.existingKeys, contains('totalOrderTotalAmount'));
      expect(arbManager.existingKeys, contains('hiNameWelcomeName'));
    });

    test('leaves non-UI strings and ignored files untouched', () {
      const source = '''
import 'package:flutter/foundation.dart';

void setup() {
  debugPrint("Debug info only");
  final path = "assets/images/logo.png";
}
''';

      final result = rewriter.rewrite(source, filePath: 'lib/util.dart');
      expect(result.modified, isFalse);
      expect(result.stringsExtracted, equals(0));
      expect(result.newContent, equals(source));
    });
  });
}
