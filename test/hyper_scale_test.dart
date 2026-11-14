import 'dart:convert';
import 'dart:io';
import 'package:auto_localize_cli/auto_localize_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Part 1: Hyper-Scale Architecture & Scale Benchmarks', () {
    test('1. Pre-AST Lexical Fast-Reject Filter bypasses non-UI files', () {
      // Non-UI model with no string quotes
      const nonUiNoQuotes = '''
class CounterState {
  final int count;
  final bool isLoading;
  const CounterState(this.count, this.isLoading);
}
''';
      expect(
        PreAstFilter.canContainLocalizableStrings(
          nonUiNoQuotes,
          filePath: 'lib/models/counter_state.dart',
        ),
        isFalse,
      );

      // Non-UI model with string quotes but no whitelisted UI tokens
      const nonUiWithQuotes = '''
class UserDto {
  final String id;
  final String role;
  const UserDto(this.id, this.role);
  Map<String, dynamic> toJson() => {'id': id, 'role': 'admin_role'};
}
''';
      expect(
        PreAstFilter.canContainLocalizableStrings(
          nonUiWithQuotes,
          filePath: 'lib/dto/user_dto.dart',
        ),
        isFalse,
      );

      // UI Widget with Text constructor
      const uiWithText = '''
Widget build(BuildContext context) {
  return const Text("Welcome Home");
}
''';
      expect(
        PreAstFilter.canContainLocalizableStrings(
          uiWithText,
          filePath: 'lib/widgets/home_view.dart',
        ),
        isTrue,
      );

      // UI Widget with named parameter hintText:
      const uiWithNamedParam = '''
Widget build(BuildContext context) {
  return TextField(
    decoration: InputDecoration(hintText: "Enter your email"),
  );
}
''';
      expect(
        PreAstFilter.canContainLocalizableStrings(
          uiWithNamedParam,
          filePath: 'lib/widgets/login_form.dart',
        ),
        isTrue,
      );

      // app_strings.dart without UI tokens MUST always pass
      const appStrings = '''
class AppStrings {
  static String get serverError => "Server encountered an error";
}
''';
      expect(
        PreAstFilter.canContainLocalizableStrings(
          appStrings,
          filePath: 'lib/core/app_strings.dart',
        ),
        isTrue,
      );
    });

    test(
        '2. Sharded Incremental Cache on 1,000 files (900 non-UI, 100 UI) benchmark',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('scale_benchmark_');
      try {
        final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
        final l10nDir = Directory(p.join(libDir.path, 'l10n'))..createSync();
        final coreDir = Directory(p.join(libDir.path, 'core'))..createSync();

        // Setup pubspec.yaml
        final pubspec = File(p.join(tempDir.path, 'pubspec.yaml'));
        pubspec.writeAsStringSync('''
name: scale_benchmark_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
''');

        // Setup l10n.yaml
        final l10nYaml = File(p.join(tempDir.path, 'l10n.yaml'));
        l10nYaml.writeAsStringSync('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
''');

        // Setup template app_en.arb
        final arbFile = File(p.join(l10nDir.path, 'app_en.arb'));
        arbFile.writeAsStringSync('{"@@locale": "en"}');

        // Setup localization_helper.dart
        final helperFile =
            File(p.join(coreDir.path, 'localization_helper.dart'));
        helperFile.writeAsStringSync('''
import 'package:flutter/material.dart';
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();
dynamic get l10n => null;
''');

        // Generate 900 non-UI model files
        final modelsDir = Directory(p.join(libDir.path, 'models'))
          ..createSync();
        for (var i = 1; i <= 900; i++) {
          final modelFile = File(p.join(modelsDir.path, 'model_$i.dart'));
          modelFile.writeAsStringSync('''
class Model$i {
  final int id = $i;
  final String code = "CODE_$i";
  Map<String, dynamic> toJson() => {'id': id, 'code': code};
}
''');
        }

        // Generate 100 UI widget files
        final widgetsDir = Directory(p.join(libDir.path, 'widgets'))
          ..createSync();
        for (var i = 1; i <= 100; i++) {
          final widgetFile = File(p.join(widgetsDir.path, 'widget_$i.dart'));
          widgetFile.writeAsStringSync('''
import 'package:flutter/material.dart';
class Widget$i extends StatelessWidget {
  const Widget$i({super.key});
  @override
  Widget build(BuildContext context) {
    return const Text("Hello Widget $i");
  }
}
''');
        }

        // Run 1: Initial extraction
        final stopwatchRun1 = Stopwatch()..start();
        final runnerRun1 = ExtractRunner(
          projectDir: tempDir,
          workers: 4,
        );
        await runnerRun1.run();
        stopwatchRun1.stop();

        // Verify ARB has extracted keys
        final arbContent = jsonDecode(arbFile.readAsStringSync()) as Map;
        expect(arbContent.length, greaterThanOrEqualTo(100));

        // Run 2: Incremental cache hit run
        final stopwatchRun2 = Stopwatch()..start();
        final runnerRun2 = ExtractRunner(
          projectDir: tempDir,
          workers: 4,
        );
        await runnerRun2.run();
        stopwatchRun2.stop();

        // Benchmark assertions:
        // Run 2 must complete in sub-second (usually < 200ms even on 1,000 files)
        // because all 1,000 files hit the incremental cache!
        expect(stopwatchRun2.elapsedMilliseconds, lessThan(1000));
        stdout.writeln(
          '⚡ Scale Benchmark Result: Run 1 took ${stopwatchRun1.elapsedMilliseconds}ms, '
          'Run 2 (Cache Hit on 1,000 files) took ${stopwatchRun2.elapsedMilliseconds}ms!',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        '3. Deterministic Parallel Execution matches single-threaded execution',
        () async {
      final sampleFiles = [
        FileToParse(
          filePath: '/app/lib/views/login_view.dart',
          relativePath: 'lib/views/login_view.dart',
          source: '''
import 'package:flutter/material.dart';
Widget build() => const Text("Please Enter Your Credentials");
''',
          statModifiedMicros: 100,
          statSize: 100,
        ),
        FileToParse(
          filePath: '/app/lib/views/dashboard_view.dart',
          relativePath: 'lib/views/dashboard_view.dart',
          source: '''
import 'package:flutter/material.dart';
Widget build() => const Text("Welcome Back to Your Dashboard");
''',
          statModifiedMicros: 200,
          statSize: 200,
        ),
        FileToParse(
          filePath: '/app/lib/core/app_strings.dart',
          relativePath: 'lib/core/app_strings.dart',
          source: '''
class AppStrings {
  static String get timeoutError => "Connection to the host has timed out";
}
''',
          statModifiedMicros: 300,
          statSize: 300,
        ),
      ];

      // Single worker parse
      final singleParsed = await parseCandidateBatch(sampleFiles, workers: 1);
      singleParsed.sort((a, b) => a.filePath.compareTo(b.filePath));

      // Multi-core parallel parse
      final parallelParsed = await parseCandidateBatch(sampleFiles, workers: 4);
      parallelParsed.sort((a, b) => a.filePath.compareTo(b.filePath));

      expect(parallelParsed.length, equals(singleParsed.length));
      for (var i = 0; i < singleParsed.length; i++) {
        expect(parallelParsed[i].filePath, equals(singleParsed[i].filePath));
        expect(
          parallelParsed[i].candidates.length,
          equals(singleParsed[i].candidates.length),
        );
        for (var j = 0; j < singleParsed[i].candidates.length; j++) {
          expect(
            parallelParsed[i].candidates[j].rawValue,
            equals(singleParsed[i].candidates[j].rawValue),
          );
          expect(
            parallelParsed[i].candidates[j].reconstructedText,
            equals(singleParsed[i].candidates[j].reconstructedText),
          );
        }
      }
    });
  });
}
