import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:auto_localize_cli/src/analyzer/ast_visitor.dart';
import 'package:auto_localize_cli/src/analyzer/cache_manager.dart';
import 'package:auto_localize_cli/src/analyzer/code_rewriter.dart';
import 'package:auto_localize_cli/src/analyzer/pre_ast_filter.dart';
import 'package:auto_localize_cli/src/generator/arb_manager.dart';
import 'package:auto_localize_cli/src/setup/init_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('v1.1.0 Production Hardening & Fixes', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('auto_localize_v110_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'Task 1 & 2: InitRunner configures intl: any, l10n.yaml output-dir, and no markDirty in localization_helper',
        () async {
      final pubspecFile = File(p.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_app
description: A new Flutter project.
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''');

      final runner = InitRunner(projectDir: tempDir, autoRunFlutter: false);
      await runner.run();

      // 1. Verify pubspec.yaml contains 'intl: any'
      final updatedPubspec = await pubspecFile.readAsString();
      expect(updatedPubspec, contains('intl: any'));
      expect(updatedPubspec, isNot(contains("intl: '^0.19.0'")));

      // 2. Verify l10n.yaml determinism
      final l10nYamlFile = File(p.join(tempDir.path, 'l10n.yaml'));
      expect(await l10nYamlFile.exists(), isTrue);
      final l10nContent = await l10nYamlFile.readAsString();
      expect(l10nContent, contains('output-dir: lib/l10n'));

      // 3. Verify localization_helper.dart does NOT contain unsafe markDirty
      final helperFile = File(
        p.join(tempDir.path, 'lib', 'core', 'localization',
            'localization_helper.dart'),
      );
      expect(await helperFile.exists(), isTrue);
      final helperContent = await helperFile.readAsString();
      expect(helperContent, isNot(contains('markDirty')));
      expect(helperContent, contains('localeNotifier.value = locale;'));
      expect(helperContent, contains('_overrideLocale = locale;'));
    });

    test(
        'Task 3: PreAstFilter recognizes UI helper tokens and named parameters',
        () {
      final tokens = [
        'buttonText:',
        'action:',
        'prompt:',
        'showToast',
        'showSnackBar',
        'showDialog',
        'showAlert',
      ];

      for (final token in tokens) {
        final source = 'void show() { $token("Test message"); }';
        expect(
          PreAstFilter.canContainLocalizableStrings(source,
              filePath: 'lib/view.dart'),
          isTrue,
          reason: 'Token $token should pass PreAstFilter',
        );
      }
    });

    test(
        'Task 4.1: Method/Getter restriction extracts only from *Strings/*Errors/*Messages/*Constants classes',
        () {
      const code = '''
import 'package:flutter/material.dart';

class ApiService {
  String get endpoint => 'https://api.example.com/v1';
  String fetchToken() => 'secret_token_123';
}

class AppStrings {
  static String get loginTitle => 'Please log in to continue';
}

class ErrorMessages {
  static String get networkError => 'Unable to connect to server';
}
''';

      final parseResult = parseString(content: code);
      final visitor = LocalizationAstVisitor();
      parseResult.unit.accept(visitor);

      final extractedTexts =
          visitor.candidates.map((e) => e.reconstructedText).toList();

      // Technical endpoints in ApiService must NOT be extracted
      expect(extractedTexts, isNot(contains('https://api.example.com/v1')));
      expect(extractedTexts, isNot(contains('secret_token_123')));

      // UI strings in AppStrings and ErrorMessages MUST be extracted
      expect(extractedTexts, contains('Please log in to continue'));
      expect(extractedTexts, contains('Unable to connect to server'));
    });

    test('Task 4.2: Preserves inline comments when removing const keyword',
        () async {
      const source = '''
import 'package:flutter/material.dart';

Widget build(BuildContext context) {
  return const /* keep comment */ Column(
    children: [
      Text('Hello World'),
    ],
  );
}
''';

      final arbFile = File(p.join(tempDir.path, 'app_en.arb'));
      arbFile.writeAsStringSync('{"@@locale": "en"}');
      final arbManager = ArbManager(arbFile: arbFile);
      await arbManager.load();

      final rewriter = CodeRewriter(
        arbManager: arbManager,
        packageName: 'test_app',
      );

      final result = rewriter.rewrite(source, filePath: 'lib/test_view.dart');
      expect(result.newContent, contains('/* keep comment */ Column('));
      expect(result.newContent, contains('Text(l10n.helloWorld)'));
    });

    test(
        'Task 4.3: Raw string interpolations (r"...") are ignored and not treated as interpolations',
        () {
      const code = r'''
import 'package:flutter/material.dart';

Widget build(BuildContext context) {
  return Text(r'Price is $amount');
}
''';

      final parseResult = parseString(content: code);
      final visitor = LocalizationAstVisitor();
      parseResult.unit.accept(visitor);

      // Raw strings should not produce parameterized interpolations
      for (final candidate in visitor.candidates) {
        expect(candidate.placeholders, isEmpty);
      }
    });

    test(
        'Task 5.1: Safe import insertion preserves leading comments (e.g. // ignore_for_file)',
        () async {
      const source = '''// ignore_for_file: avoid_print, unused_local_variable

class SimpleScreen {
  Widget build() {
    return Text('Welcome Home');
  }
}
''';

      final arbFile = File(p.join(tempDir.path, 'app_en.arb'));
      arbFile.writeAsStringSync('{"@@locale": "en"}');
      final arbManager = ArbManager(arbFile: arbFile);
      await arbManager.load();

      final rewriter = CodeRewriter(
        arbManager: arbManager,
        packageName: 'test_app',
      );

      final result = rewriter.rewrite(
        source,
        filePath: 'lib/screens/simple_screen.dart',
      );

      expect(result.newContent.startsWith('// ignore_for_file: avoid_print'),
          isTrue);
      expect(
          result.newContent,
          contains(
              "import 'package:test_app/core/localization/localization_helper.dart';"));
    });

    test(
        'Task 5.2: External ARB modification/deletion invalidates IncrementalCacheManager',
        () async {
      final arbFile = File(p.join(tempDir.path, 'lib', 'l10n', 'app_en.arb'));
      await arbFile.parent.create(recursive: true);
      await arbFile.writeAsString('{"@@locale": "en"}');

      final initialStat = arbFile.statSync();
      final initialSig =
          '${initialStat.modified.microsecondsSinceEpoch}:${initialStat.size}';

      final cache = IncrementalCacheManager(
        projectDir: tempDir,
        arbSignature: initialSig,
      );

      final testFile = File(p.join(tempDir.path, 'lib', 'test_file.dart'));
      await testFile.writeAsString('class Test {}');
      final testStat = testFile.statSync();

      // Record clean with initial ARB signature
      cache.recordFileClean('lib/test_file.dart', testStat);
      await cache.flush();

      // Cache hit under initial signature
      expect(cache.isFileClean('lib/test_file.dart', testStat), isTrue);

      // Now simulate external modification of ARB (e.g. user manually deleted keys)
      await Future.delayed(const Duration(milliseconds: 20));
      await arbFile.writeAsString('{"@@locale": "en", "modified": true}');
      final modifiedStat = arbFile.statSync();
      final modifiedSig =
          '${modifiedStat.modified.microsecondsSinceEpoch}:${modifiedStat.size}';

      // A new cache manager instance created with the updated ARB signature must MISS
      final nextCache = IncrementalCacheManager(
        projectDir: tempDir,
        arbSignature: modifiedSig,
      );

      expect(nextCache.isFileClean('lib/test_file.dart', testStat), isFalse);
    });

    test(
        'Edge-Cases Guard: Enum constants, switch cases, equality comparisons, and map keys are never extracted',
        () async {
      const source = '''
import 'package:flutter/material.dart';

enum Trigger {
  power(
    title: 'Hold Power button',
    subtitle: 'Replaces Google Assistant',
  );
  final String title;
  final String subtitle;
  const Trigger({required this.title, required this.subtitle});
}

void testContext(dynamic json, String status) {
  // Switch case
  switch (status) {
    case 'pending':
      print('Status is pending');
      break;
  }

  // Equality comparison
  if (status == 'active') {
    // UI widget inside branch SHOULD be extracted
    showDialog(title: 'Welcome Active User');
  }

  // Map index lookup and map key
  final x = json['title'];
  final config = {'label': 'Non-UI Config'};
}
''';

      final arbFile = File(p.join(tempDir.path, 'app_en.arb'));
      arbFile.writeAsStringSync('{"@@locale": "en"}');
      final arbManager = ArbManager(arbFile: arbFile);
      await arbManager.load();

      final rewriter = CodeRewriter(
        arbManager: arbManager,
        packageName: 'test_app',
      );

      final result = rewriter.rewrite(source, filePath: 'lib/edge_cases.dart');
      expect(result.modified, isTrue);

      // 1. Enum constant strings MUST be untouched
      expect(result.newContent, contains("title: 'Hold Power button'"));
      expect(
          result.newContent, contains("subtitle: 'Replaces Google Assistant'"));
      expect(result.newContent, isNot(contains('l10n.holdPowerButton')));

      // 2. Switch case MUST be untouched
      expect(result.newContent, contains("case 'pending':"));

      // 3. Comparison MUST be untouched
      expect(result.newContent, contains("status == 'active'"));

      // 4. Map index lookup and key MUST be untouched
      expect(result.newContent, contains("json['title']"));
      expect(result.newContent, contains("'label': 'Non-UI Config'"));

      // 5. Genuine UI string inside showDialog MUST be extracted
      expect(result.newContent,
          contains('showDialog(title: l10n.welcomeActiveUser)'));
    });
  });
}
