import 'dart:io';
import 'package:auto_localize_cli/auto_localize_cli.dart';
import 'package:test/test.dart';

void main() {
  group('Part 1 & 2: Comprehensive auto_localize_cli Test Suite', () {
    const keyGen = KeyGenerator();
    late Directory tempDir;
    late File arbFile;
    late ArbManager arbManager;
    late CodeRewriter rewriter;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('full_test_');
      arbFile = File('${tempDir.path}/app_en.arb');
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

    // Case 1
    test('1. "404 Page Not Found" -> page404NotFound', () {
      final key = keyGen.generateKey('404 Page Not Found');
      expect(key, equals('page404NotFound'));
    });

    // Case 2
    test('2. "24 7 Customer Support Available" -> customer247Available', () {
      final key = keyGen.generateKey('24 7 Customer Support Available');
      expect(key, equals('customer247Available'));
    });

    // Case 3
    test('3. "Continue" -> continueText & "Return" -> returnText', () {
      expect(keyGen.generateKey('Continue'), equals('continueText'));
      expect(keyGen.generateKey('Return'), equals('returnText'));
    });

    // Case 4 & 5
    test('4 & 5. Account status messages produce distinct meaningful keys', () {
      final suspended = keyGen.generateKey('Your account has been temporarily suspended');
      final deleted = keyGen.generateKey('Your account has been permanently deleted');
      final verified = keyGen.generateKey('Your account has been successfully verified');

      expect(suspended, equals('yourAccountHasSuspended'));
      expect(deleted, equals('yourAccountHasDeleted'));
      expect(verified, equals('yourAccountHasVerified'));
    });

    // Case 6
    test('6. Collision with same first 3 words & same last word falls back to 2nd-last word', () {
      final existing = <String>{'yourCurrentLoginAgain'};
      final key = keyGen.generateKey(
        'Your current login session has expired please try again',
        existingKeys: existing,
      );
      // Fallback takes 2nd-last word 'try' -> yourCurrentLoginTry
      expect(key, equals('yourCurrentLoginTry'));

      // If that's also taken, falls back to 3rd-last word 'please'
      final existing2 = <String>{'yourCurrentLoginAgain', 'yourCurrentLoginTry'};
      final key2 = keyGen.generateKey(
        'Your current login session has expired please try again',
        existingKeys: existing2,
      );
      expect(key2, equals('yourCurrentLoginPlease'));

      // If all fallbacks are taken, falls back to numeric suffix
      final existing3 = <String>{
        'yourCurrentLoginAgain',
        'yourCurrentLoginTry',
        'yourCurrentLoginPlease',
      };
      final key3 = keyGen.generateKey(
        'Your current login session has expired please try again',
        existingKeys: existing3,
      );
      expect(key3, equals('yourCurrentLoginAgain2'));
    });

    // Case 7
    test('7. Pure numbers, symbol-numbers, and emails are strictly ignored', () {
      expect(keyGen.shouldIgnore('2026'), isTrue);
      expect(keyGen.shouldIgnore('100%'), isTrue);
      expect(keyGen.shouldIgnore('+91-9876543210'), isTrue);
      expect(keyGen.shouldIgnore('₹500'), isTrue);
      expect(keyGen.shouldIgnore('---'), isTrue);
      expect(keyGen.shouldIgnore('example@domain.com'), isTrue);
      expect(keyGen.generateKey('2026'), isNull);
      expect(keyGen.generateKey('100%'), isNull);
      expect(keyGen.generateKey('+91-9876543210'), isNull);
    });

    // Case 8
    test('8. StringInterpolation: simple variables, properties, binary exprs, and deduplication', () {
      const source = '''
import 'package:flutter/material.dart';

class OrderDetailsView extends StatelessWidget {
  final String userName;
  final dynamic order;
  final String firstName;
  final String lastName;
  const OrderDetailsView({
    super.key,
    required this.userName,
    required this.order,
    required this.firstName,
    required this.lastName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("2026"),
        const Text("100%"),
        const Text("+91-9876543210"),
        Text("\$firstName \$lastName"),
        Text("₹\${order.totalAmount}"),
        Text("Order #\${order.id} has \${order.itemCount + 1} items for \$userName"),
        Text("Hi \$userName, welcome back \$userName!"),
      ],
    );
  }
}
''';

      final result = rewriter.rewrite(source, filePath: 'lib/order_view.dart');
      expect(result.modified, isTrue);

      // Ignored strings remain untouched
      expect(result.newContent, contains('const Text("2026")'));
      expect(result.newContent, contains('const Text("100%")'));
      expect(result.newContent, contains('const Text("+91-9876543210")'));
      expect(result.newContent, contains(r'Text("$firstName $lastName")'));
      expect(result.newContent, contains(r'Text("₹${order.totalAmount}")'));

      // Interpolation with multiple expressions passes all 3 arguments
      expect(
        result.newContent,
        contains(
          '(order.id, order.itemCount + 1, userName)',
        ),
      );

      // Duplicate expression in same string passes argument only once
      expect(
        result.newContent,
        contains('(userName)'),
      );
    });

    // Case 9
    test('9. app_strings.dart extracts both getters and parameterized regular methods', () {
      const source = '''
import 'localization_helper.dart';

class AppStrings {
  AppStrings._();

  static String get networkError => "Please check your internet connection";

  static String get sessionExpired =>
      "Your current login session has expired please login again";

  static String welcomeUser(String name, int count) =>
      "Welcome back \$name, you have \$count pending notifications";
}
''';

      final result = rewriter.rewrite(source, filePath: 'lib/core/app_strings.dart');
      expect(result.modified, isTrue);
      expect(result.stringsExtracted, equals(3));

      expect(
        result.newContent,
        contains('static String get networkError => l10n.pleaseCheckYourConnection;'),
      );
      expect(
        result.newContent,
        contains(
          'l10n.welcomeBackNameNotifications(name, count);',
        ),
      );
    });
  });
}
