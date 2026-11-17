import 'dart:io';
import 'package:auto_localize_cli/auto_localize_cli.dart';
import 'package:test/test.dart';

void main() {
  group('v1.0.7 Architectural Fixes & Adversarial Verifications', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('v107_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        '1. ARB load failure throws FormatException without wiping existing ARB',
        () async {
      final arbFile = File('${tempDir.path}/app_en.arb');
      await arbFile.writeAsString(
          '<<<<<<< HEAD\n{"hello": "world"}\n=======\n{"hello": "earth"}\n>>>>>>> branch');

      final arbManager = ArbManager(arbFile: arbFile);
      expect(() async => await arbManager.load(), throwsFormatException);

      // Verify file was NOT wiped
      final content = await arbFile.readAsString();
      expect(content, contains('<<<<<<< HEAD'));
    });

    test('2. Literal unparameterized braces are escaped as \'{braces}\' in ARB',
        () async {
      final arbFile = File('${tempDir.path}/app_en.arb');
      final arbManager = ArbManager(arbFile: arbFile);
      await arbManager.load();

      arbManager.getOrAdd("It's {braces} and 'quotes'");
      await arbManager.save();

      final saved = await arbFile.readAsString();
      expect(saved, contains("It's '{'braces'}' and 'quotes'"));
    });

    test('3. Non-Latin scripts generate stable 32-bit FNV-1a hash keys', () {
      const keyGen = KeyGenerator();
      final key1 = keyGen.generateKey('আমার সোনার বাংলা আমি তোমায় ভালোবাসি');
      final key2 = keyGen.generateKey('আমার সোনার বাংলা আমি তোমায় ভালোবাসি');

      expect(key1, isNotNull);
      expect(key1, startsWith('msg'));
      expect(key1, equals(key2));

      // Hindi
      final hindiKey = keyGen.generateKey('नमस्ते दुनिया आप कैसे हैं');
      expect(hindiKey, startsWith('msg'));

      // Arabic
      final arabicKey = keyGen.generateKey('مرحبا بك في العالم');
      expect(arabicKey, startsWith('msg'));

      // Chinese
      final chineseKey = keyGen.generateKey('你好世界欢迎来到这里');
      expect(chineseKey, startsWith('msg'));
    });

    test(
        '4. Flutter AppLocalizations reserved keywords get disambiguated with Text suffix',
        () {
      const keyGen = KeyGenerator();
      expect(keyGen.generateKey('Supported Locales'),
          equals('supportedLocalesText'));
      expect(keyGen.generateKey('Localizations Delegates'),
          equals('localizationsDelegatesText'));
      expect(keyGen.generateKey('Delegate'), equals('delegateText'));
      expect(keyGen.generateKey('Default'), equals('defaultText'));
      expect(keyGen.generateKey('Class'), equals('classText'));
    });

    test('5. Non-UI invocations (Exception, Color, Uri) are not extracted',
        () async {
      final arbFile = File('${tempDir.path}/app_en.arb');
      final arbManager = ArbManager(arbFile: arbFile);
      await arbManager.load();
      final rewriter =
          CodeRewriter(arbManager: arbManager, packageName: 'my_app');

      const source = '''
import 'package:flutter/material.dart';

void test() {
  throw Exception('Something bad');
  final c = Color(0xFFFFFFFF);
  final u = Uri.parse('https://example.com');
  print('Debug log');
}
''';
      final result = rewriter.rewrite(source, filePath: 'lib/test.dart');
      expect(result.stringsExtracted, equals(0));
      expect(result.newContent, equals(source));
    });

    test('6. Top-level const variable with Text converts const to final',
        () async {
      final arbFile = File('${tempDir.path}/app_en.arb');
      final arbManager = ArbManager(arbFile: arbFile);
      await arbManager.load();
      final rewriter =
          CodeRewriter(arbManager: arbManager, packageName: 'my_app');

      const source = '''
import 'package:flutter/material.dart';

const topLevelWidgets = [
  Text('Top level title'),
];
''';
      final result = rewriter.rewrite(source, filePath: 'lib/top.dart');
      expect(result.stringsExtracted, equals(1));
      expect(result.newContent, contains('final topLevelWidgets = ['));
      expect(result.newContent, contains('Text(l10n.topLevelTitle)'));
    });

    test('7. ExtractRunner Dry-Run mode does not write to disk', () async {
      final libDir = Directory('${tempDir.path}/lib')
        ..createSync(recursive: true);
      final l10nDir = Directory('${tempDir.path}/lib/l10n')
        ..createSync(recursive: true);
      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec
          .writeAsString('name: test_dry_run\nenvironment:\n  sdk: ^3.0.0\n');

      final arb = File('${l10nDir.path}/app_en.arb');
      await arb.writeAsString('{\n  "@@locale": "en"\n}\n');

      final dartFile = File('${libDir.path}/main.dart');
      const originalCode = '''
import 'package:flutter/material.dart';
Widget build(BuildContext context) => const Text('Dry Run Text');
''';
      await dartFile.writeAsString(originalCode);

      final runner = ExtractRunner(
        projectDir: tempDir,
        dryRun: true,
      );
      await runner.run();

      // Dart file and ARB must be unchanged
      expect(await dartFile.readAsString(), equals(originalCode));
      final arbContent = await arb.readAsString();
      expect(arbContent, isNot(contains('dryRunText')));
    });

    test('8. ExtractRunner single-file targeting only processes specified file',
        () async {
      final libDir = Directory('${tempDir.path}/lib')
        ..createSync(recursive: true);
      final l10nDir = Directory('${tempDir.path}/lib/l10n')
        ..createSync(recursive: true);
      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec
          .writeAsString('name: test_single\nenvironment:\n  sdk: ^3.0.0\n');

      final arb = File('${l10nDir.path}/app_en.arb');
      await arb.writeAsString('{\n  "@@locale": "en"\n}\n');

      final targetFile = File('${libDir.path}/target.dart');
      await targetFile.writeAsString(
          "import 'package:flutter/material.dart';\nWidget f() => const Text('Target File Text');\n");

      final untouchedFile = File('${libDir.path}/other.dart');
      const untouchedCode =
          "import 'package:flutter/material.dart';\nWidget g() => const Text('Untouched File Text');\n";
      await untouchedFile.writeAsString(untouchedCode);

      final runner = ExtractRunner(
        projectDir: tempDir,
        targetFilePath: 'lib/target.dart',
      );
      await runner.run();

      // Target file should be modified
      final targetContent = await targetFile.readAsString();
      expect(targetContent, contains('l10n.targetFileText'));

      // Untouched file should NOT be modified
      final untouchedContent = await untouchedFile.readAsString();
      expect(untouchedContent, equals(untouchedCode));
    });
  });
}
