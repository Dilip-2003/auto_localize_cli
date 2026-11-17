import 'dart:io';
import 'package:auto_localize_cli/src/setup/init_runner.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('InitRunner', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('init_test_');
      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec.writeAsString('''name: sample_flutter_app
description: A sample app for testing.
version: 1.0.0

environment:
  sdk: ^3.0.0

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('scaffolds all localization files and updates pubspec.yaml', () async {
      final runner = InitRunner(projectDir: tempDir);
      await runner.run();

      // Check pubspec.yaml updates
      final updatedPubspec =
          await File('${tempDir.path}/pubspec.yaml').readAsString();
      final yaml = loadYaml(updatedPubspec) as YamlMap;
      final deps = yaml['dependencies'] as YamlMap;
      expect(deps.containsKey('flutter_localizations'), isTrue);
      expect(deps.containsKey('intl'), isTrue);
      final flutter = yaml['flutter'] as YamlMap;
      expect(flutter['generate'], isTrue);

      // Check l10n.yaml
      final l10nFile = File('${tempDir.path}/l10n.yaml');
      expect(await l10nFile.exists(), isTrue);
      final l10nContent = await l10nFile.readAsString();
      expect(l10nContent, contains('template-arb-file: app_en.arb'));

      // Check app_en.arb
      final arbFile = File('${tempDir.path}/lib/l10n/app_en.arb');
      expect(await arbFile.exists(), isTrue);
      final arbContent = await arbFile.readAsString();
      expect(arbContent, contains('"@@locale": "en"'));

      // Check localization_helper.dart
      final helperFile = File(
          '${tempDir.path}/lib/core/localization/localization_helper.dart');
      expect(await helperFile.exists(), isTrue);
      final helperContent = await helperFile.readAsString();
      expect(helperContent, contains('globalNavigatorKey'));
      expect(helperContent, contains('AppLocalizations get l10n'));

      // Check app_strings.dart
      final appStringsFile =
          File('${tempDir.path}/lib/core/localization/app_strings.dart');
      expect(await appStringsFile.exists(), isTrue);
    });
  });
}
