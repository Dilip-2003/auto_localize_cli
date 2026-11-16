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
      final suspended =
          keyGen.generateKey('Your account has been temporarily suspended');
      final deleted =
          keyGen.generateKey('Your account has been permanently deleted');
      final verified =
          keyGen.generateKey('Your account has been successfully verified');

      expect(suspended, equals('yourAccountHasSuspended'));
      expect(deleted, equals('yourAccountHasDeleted'));
      expect(verified, equals('yourAccountHasVerified'));
    });

    // Case 6
    test(
        '6. Collision with same first 3 words & same last word falls back to 2nd-last word',
        () {
      final existing = <String>{'yourCurrentLoginAgain'};
      final key = keyGen.generateKey(
        'Your current login session has expired please try again',
        existingKeys: existing,
      );
      // Fallback takes 2nd-last word 'try' -> yourCurrentLoginTry
      expect(key, equals('yourCurrentLoginTry'));

      // If that's also taken, falls back to 3rd-last word 'please'
      final existing2 = <String>{
        'yourCurrentLoginAgain',
        'yourCurrentLoginTry'
      };
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
    test('7. Pure numbers, symbol-numbers, and emails are strictly ignored',
        () {
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
    test(
        '8. StringInterpolation: simple variables, properties, binary exprs, and deduplication',
        () {
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
    test(
        '9. app_strings.dart extracts getters, const fields, and parameterized regular methods',
        () {
      const source = '''
import 'localization_helper.dart';

class AppStrings {
  AppStrings._();

  static String get networkError => "Please check your internet connection";

  static String get sessionExpired =>
      "Your current login session has expired please login again";

  // Case 3: static const String field
  static const String constantError = "Database connection timeout occurred";

  static String welcomeUser(String name, int count) =>
      "Welcome back \$name, you have \$count pending notifications";
}
''';

      final result = rewriter.rewrite(source,
          filePath: 'lib/core/localization/app_strings.dart');
      expect(result.modified, isTrue);
      expect(result.stringsExtracted, equals(4));

      expect(
        result.newContent,
        contains(
            'static String get networkError => l10n.pleaseCheckYourConnection;'),
      );
      expect(
        result.newContent,
        contains(
            'static String get constantError => l10n.databaseConnectionTimeoutOccurred;'),
      );
      expect(
        result.newContent,
        contains(
          'l10n.welcomeBackNameNotifications(name, count);',
        ),
      );
    });

    // Case 10: part / part of handling
    test(
        '10. part of file does not receive import; parent file receives import',
        () async {
      final featureDir = Directory('${tempDir.path}/features');
      await featureDir.create(recursive: true);

      final parentFile = File('${featureDir.path}/orders_cubit.dart');
      await parentFile.writeAsString('''
import 'package:flutter/foundation.dart';

part 'orders_state.dart';

class OrdersCubit {}
''');

      final partFile = File('${featureDir.path}/orders_state.dart');
      final partSource = '''
part of 'orders_cubit.dart';

class OrdersState {
  final String message;
  const OrdersState(this.message);

  factory OrdersState.initial() => const OrdersState("Initial orders status");
}
''';
      await partFile.writeAsString(partSource);

      final result = rewriter.rewrite(partSource, filePath: partFile.path);
      expect(result.modified, isTrue);
      // Part file must NOT contain import directive!
      expect(result.newContent.contains("import '"), isFalse);
      expect(result.newContent, contains('l10n.initialOrdersStatus'));

      // Parent file MUST contain the localization_helper import
      final parentUpdated = await parentFile.readAsString();
      expect(
          parentUpdated,
          contains(
              "import 'package:test_app/core/localization/localization_helper.dart';"));
    });

    // Case 11: Ignored default parameter, constructor initializer, and asserts
    test(
        '11. Default formal parameters, constructor super initializers, and asserts are ignored',
        () {
      const source = '''
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String title;
  const CustomButton({
    super.key,
    this.title = "Default Button Label",
  }) : assert(title.length > 0, "Title cannot be empty");

  @override
  Widget build(BuildContext context) {
    assert(context.mounted, "Context must be mounted");
    return Text(title);
  }
}
''';

      final result =
          rewriter.rewrite(source, filePath: 'lib/custom_button.dart');
      expect(result.modified, isFalse);
      expect(
          result.newContent, contains('this.title = "Default Button Label"'));
      expect(result.newContent, contains('"Title cannot be empty"'));
      expect(result.newContent, contains('"Context must be mounted"'));
    });

    // Case 12: Multilingual / Russian Cyrillic transliteration support
    test(
        '12. Cyrillic and international text generates valid Latin camelCase Dart getters',
        () {
      expect(keyGen.generateKey('Привет мир'), equals('privetMir'));
      expect(
          keyGen.generateKey('Служба поддержки'), equals('sluzhbaPodderzhki'));
      expect(keyGen.generateKey('24 7 Служба поддержки доступна'),
          equals('sluzhba247Dostupna'));
    });

    // Case 13: Custom default locale in InitRunner
    test('13. InitRunner scaffolds custom locale template ARB and l10n.yaml',
        () async {
      final customDir = Directory('${tempDir.path}/custom_ru_app');
      await customDir.create(recursive: true);

      final pubspec = File('${customDir.path}/pubspec.yaml');
      await pubspec.writeAsString('''name: custom_ru_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
''');

      final initRunner = InitRunner(projectDir: customDir, defaultLocale: 'ru');
      await initRunner.run();

      final l10nYaml = File('${customDir.path}/l10n.yaml');
      expect(await l10nYaml.exists(), isTrue);
      expect(await l10nYaml.readAsString(),
          contains('template-arb-file: app_ru.arb'));

      final arbRu = File('${customDir.path}/lib/l10n/app_ru.arb');
      expect(await arbRu.exists(), isTrue);
      expect(await arbRu.readAsString(), contains('"@@locale": "ru"'));
    });

    // Case 14: Pre-AST Lexical Fast-Reject Filter
    test('14. Pre-AST Lexical Fast-Reject Filter bypasses non-UI files', () {
      const nonUiModel = '''
class UserDto {
  final String id;
  final String role;
  const UserDto(this.id, this.role);
}
''';
      expect(
        PreAstFilter.canContainLocalizableStrings(
          nonUiModel,
          filePath: 'lib/models/user_dto.dart',
        ),
        isFalse,
      );

      const uiWidget = '''
Widget build(BuildContext context) => const Text("Hello World");
''';
      expect(
        PreAstFilter.canContainLocalizableStrings(
          uiWidget,
          filePath: 'lib/views/home.dart',
        ),
        isTrue,
      );
    });

    // Case 15: Deterministic parallel AST candidate parsing
    test(
        '15. Deterministic parallel AST candidate parsing matches single-thread',
        () async {
      final sampleFiles = [
        FileToParse(
          filePath: '/app/lib/views/home.dart',
          relativePath: 'lib/views/home.dart',
          source: 'Widget build() => const Text("Welcome Home");',
          statModifiedMicros: 100,
          statSize: 100,
        ),
      ];

      final single = await parseCandidateBatch(sampleFiles, workers: 1);
      final parallel = await parseCandidateBatch(sampleFiles, workers: 2);

      expect(parallel.length, equals(single.length));
      expect(
          parallel[0].candidates.length, equals(single[0].candidates.length));
      expect(
        parallel[0].candidates[0].rawValue,
        equals(single[0].candidates[0].rawValue),
      );
    });
  });
}
