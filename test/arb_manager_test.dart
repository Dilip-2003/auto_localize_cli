import 'dart:io';
import 'package:auto_localize_cli/src/generator/arb_manager.dart';
import 'package:test/test.dart';

void main() {
  group('ArbManager', () {
    late Directory tempDir;
    late File arbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('arb_test_');
      arbFile = File('${tempDir.path}/app_en.arb');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads empty/new ARB file and sets @@locale: en', () async {
      final manager = ArbManager(arbFile: arbFile);
      await manager.load();
      await manager.save();

      expect(await arbFile.exists(), isTrue);
      final content = await arbFile.readAsString();
      expect(content, contains('"@@locale": "en"'));
    });

    test('getOrAdd deduplicates identical strings', () async {
      final manager = ArbManager(arbFile: arbFile);
      await manager.load();

      final key1 = manager.getOrAdd('Continue');
      final key2 = manager.getOrAdd('Continue');

      expect(key1, equals('continueText'));
      expect(key2, equals('continueText'));
      expect(manager.existingKeys.length, equals(1));
    });

    test('saves and reloads existing keys', () async {
      final manager = ArbManager(arbFile: arbFile);
      await manager.load();

      manager.getOrAdd('404 Page Not Found');
      manager.getOrAdd('Your account has been temporarily suspended');
      await manager.save();

      final reloadedManager = ArbManager(arbFile: arbFile);
      await reloadedManager.load();

      expect(reloadedManager.existingKeys, contains('page404NotFound'));
      expect(reloadedManager.existingKeys, contains('yourAccountHasSuspended'));
      expect(reloadedManager.reverseMap['404 Page Not Found'], equals('page404NotFound'));
    });

    test('saves parameterized keys with @key placeholders metadata', () async {
      final manager = ArbManager(arbFile: arbFile);
      await manager.load();

      final key = manager.getOrAdd(
        'Hello {userName}',
        keyText: 'Hello userName',
        placeholders: ['userName'],
      );

      expect(key, equals('helloUserName'));
      await manager.save();

      final content = await arbFile.readAsString();
      expect(content, contains('"helloUserName": "Hello {userName}"'));
      expect(content, contains('"@helloUserName": {'));
      expect(content, contains('"placeholders": {'));
      expect(content, contains('"userName": {}'));
    });
  });
}
