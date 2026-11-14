import 'dart:convert';
import 'dart:io';
import 'package:auto_localize_cli/src/analyzer/extract_runner.dart';
import 'package:test/test.dart';

void main() {
  group('ExtractRunner End-to-End', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('extract_e2e_');

      // pubspec.yaml
      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec.writeAsString('''name: test_sample
description: Integration test app.
version: 1.0.0
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
''');

      // l10n.yaml
      final l10n = File('${tempDir.path}/l10n.yaml');
      await l10n.writeAsString('''arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
''');

      // lib/l10n/app_en.arb
      final arbFile = File('${tempDir.path}/lib/l10n/app_en.arb');
      await arbFile.parent.create(recursive: true);
      await arbFile.writeAsString('{\n  "@@locale": "en"\n}\n');

      // lib/main.dart
      final mainFile = File('${tempDir.path}/lib/main.dart');
      await mainFile.parent.create(recursive: true);
      await mainFile.writeAsString('''import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text("404 Page Not Found"),
            Text("Your account has been temporarily suspended"),
            Text("Your account has been permanently deleted"),
            Text("Continue"),
            Text("2026"),
          ],
        ),
      ),
    );
  }
}
''');

      // lib/core/app_strings.dart
      final appStringsFile = File('${tempDir.path}/lib/core/app_strings.dart');
      await appStringsFile.parent.create(recursive: true);
      await appStringsFile.writeAsString('''class AppStrings {
  AppStrings._();

  static String get networkError => "Please check your internet connection";
}
''');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'extracts all UI strings, core errors, removes consts, and updates ARB',
        () async {
      final runner = ExtractRunner(projectDir: tempDir);
      await runner.run();

      // 1. Verify app_en.arb
      final arbFile = File('${tempDir.path}/lib/l10n/app_en.arb');
      expect(await arbFile.exists(), isTrue);
      final arbContent = await arbFile.readAsString();
      final arbJson = json.decode(arbContent) as Map<String, dynamic>;

      expect(arbJson['@@locale'], equals('en'));
      expect(arbJson['page404NotFound'], equals('404 Page Not Found'));
      expect(
        arbJson['yourAccountHasSuspended'],
        equals('Your account has been temporarily suspended'),
      );
      expect(
        arbJson['yourAccountHasDeleted'],
        equals('Your account has been permanently deleted'),
      );
      expect(arbJson['continueText'], equals('Continue'));
      expect(
        arbJson['pleaseCheckYourConnection'],
        equals('Please check your internet connection'),
      );
      expect(arbJson.containsKey('text2026'), isFalse);
      expect(arbJson.containsKey('2026'), isFalse);

      // 2. Verify lib/main.dart
      final mainContent =
          await File('${tempDir.path}/lib/main.dart').readAsString();
      expect(mainContent, contains('Text(l10n.page404NotFound)'));
      expect(mainContent, contains('Text(l10n.yourAccountHasSuspended)'));
      expect(mainContent, contains('Text(l10n.yourAccountHasDeleted)'));
      expect(mainContent, contains('Text(l10n.continueText)'));
      expect(mainContent, contains('Text("2026")'));
      expect(mainContent, isNot(contains('const MaterialApp')));
      expect(
          mainContent,
          contains(
              "import 'package:test_sample/core/localization_helper.dart';"));

      // 3. Verify lib/core/app_strings.dart
      final stringsContent =
          await File('${tempDir.path}/lib/core/app_strings.dart')
              .readAsString();
      expect(
        stringsContent,
        contains(
            'static String get networkError => l10n.pleaseCheckYourConnection;'),
      );
      expect(
        stringsContent,
        contains("import 'package:test_sample/core/localization_helper.dart';"),
      );
    });
  });
}
