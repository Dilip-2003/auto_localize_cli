import 'package:auto_localize_cli/src/generator/key_generator.dart';
import 'package:test/test.dart';

void main() {
  group('KeyGenerator 7-step algorithm', () {
    const generator = KeyGenerator();

    test('repositions leading numbers (404 Page Not Found -> page404NotFound)', () {
      final key = generator.generateKey('404 Page Not Found');
      expect(key, equals('page404NotFound'));
    });

    test('prunes adverbs and auxiliary words (temporarily suspended)', () {
      final key = generator.generateKey('Your account has been temporarily suspended');
      expect(key, equals('yourAccountHasSuspended'));
    });

    test('prunes adverbs and auxiliary words (permanently deleted)', () {
      final key = generator.generateKey('Your account has been permanently deleted');
      expect(key, equals('yourAccountHasDeleted'));
    });

    test('suffixes Dart reserved keyword (Continue -> continueText)', () {
      final key = generator.generateKey('Continue');
      expect(key, equals('continueText'));
    });

    test('ignores pure numeric strings (2026 -> null)', () {
      final key = generator.generateKey('2026');
      expect(key, isNull);
    });

    test('prunes long sentence to max 4 tokens (Please check your internet connection)', () {
      final key = generator.generateKey('Please check your internet connection');
      expect(key, equals('pleaseCheckYourConnection'));
    });

    test('ignores asset paths, URLs, routes', () {
      expect(generator.generateKey('assets/images/logo.png'), isNull);
      expect(generator.generateKey('https://example.com/api'), isNull);
      expect(generator.generateKey('/home'), isNull);
      expect(generator.generateKey('   '), isNull);
    });

    test('reuses existing key if text was previously mapped in reverseMap', () {
      final key = generator.generateKey(
        'Submit Form',
        reverseMap: {'Submit Form': 'customSubmitKey'},
      );
      expect(key, equals('customSubmitKey'));
    });

    test('disambiguates colliding keys', () {
      final key = generator.generateKey(
        'Welcome Back',
        existingKeys: {'welcomeBack', 'welcomeBack2'},
      );
      expect(key, equals('welcomeBack3'));
    });
  });
}
