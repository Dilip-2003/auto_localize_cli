import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Handles the initialization and scaffolding for Phase 1.
class InitRunner {
  final Directory projectDir;

  InitRunner({Directory? projectDir})
      : projectDir = projectDir ?? Directory.current;

  /// Runs the onboarding & scaffolding process.
  Future<void> run() async {
    final pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      stderr.writeln('Error: pubspec.yaml not found in ${projectDir.path}.');
      stderr.writeln(
          'Please run this command from the root of a Flutter project.');
      exitCode = 1;
      return;
    }

    stdout.writeln(
        '📦 Configuring Flutter localization dependencies in pubspec.yaml...');
    final packageName = await _configurePubspec(pubspecFile);

    stdout.writeln('⚙️  Creating l10n.yaml configuration...');
    await _createL10nYaml();

    stdout.writeln('🌐 Scaffolding template ARB file (lib/l10n/app_en.arb)...');
    await _createInitialArb();

    stdout.writeln(
        '🧩 Creating context-less global getter (lib/core/localization_helper.dart)...');
    await _createLocalizationHelper();

    stdout.writeln(
        '📝 Creating core string class (lib/core/app_strings.dart)...');
    await _createAppStrings();

    stdout.writeln('''
======================================================================
🎉 AutoLocalize initialized successfully!
======================================================================

Next Steps:
1. Run `flutter pub get` to fetch localization dependencies.
2. In your `main.dart`, configure your MaterialApp with:

   import 'package:$packageName/core/localization_helper.dart';
   import 'package:flutter_gen/gen_l10n/app_localizations.dart';

   MaterialApp(
     navigatorKey: globalNavigatorKey,
     localizationsDelegates: AppLocalizations.localizationsDelegates,
     supportedLocales: AppLocalizations.supportedLocales,
     ...
   )

3. Add hardcoded UI strings or core errors, then run:
   dart run auto_localize_cli:extract
======================================================================
''');
  }

  /// Updates pubspec.yaml with localization packages and generate: true.
  Future<String> _configurePubspec(File pubspecFile) async {
    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    final yaml = loadYaml(content) as YamlMap?;

    final packageName = yaml?['name']?.toString() ?? 'app';

    // 1. Ensure dependencies has flutter_localizations & intl
    final dependencies = yaml?['dependencies'] as YamlMap?;
    if (dependencies == null) {
      editor.update([
        'dependencies'
      ], {
        'flutter': {'sdk': 'flutter'},
        'flutter_localizations': {'sdk': 'flutter'},
        'intl': 'any',
      });
    } else {
      if (!dependencies.containsKey('flutter_localizations')) {
        editor.update(
            ['dependencies', 'flutter_localizations'], {'sdk': 'flutter'});
      }
      if (!dependencies.containsKey('intl')) {
        editor.update(['dependencies', 'intl'], 'any');
      }
    }

    // 2. Ensure flutter: generate: true
    final flutterSection = yaml?['flutter'] as YamlMap?;
    if (flutterSection == null) {
      editor.update(['flutter'], {'generate': true});
    } else {
      if (flutterSection['generate'] != true) {
        editor.update(['flutter', 'generate'], true);
      }
    }

    await pubspecFile.writeAsString(editor.toString());
    return packageName;
  }

  /// Creates l10n.yaml in the project root.
  Future<void> _createL10nYaml() async {
    final l10nFile = File(p.join(projectDir.path, 'l10n.yaml'));
    if (!await l10nFile.exists()) {
      const content = '''arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
''';
      await l10nFile.writeAsString(content);
    }
  }

  /// Creates lib/l10n/app_en.arb if not present.
  Future<void> _createInitialArb() async {
    final arbDir = Directory(p.join(projectDir.path, 'lib', 'l10n'));
    await arbDir.create(recursive: true);

    final arbFile = File(p.join(arbDir.path, 'app_en.arb'));
    if (!await arbFile.exists()) {
      const initialJson = '{\n  "@@locale": "en"\n}\n';
      await arbFile.writeAsString(initialJson);
    }
  }

  /// Creates lib/core/localization_helper.dart for context-less global getter `l10n`.
  Future<void> _createLocalizationHelper() async {
    final coreDir = Directory(p.join(projectDir.path, 'lib', 'core'));
    await coreDir.create(recursive: true);

    final helperFile = File(p.join(coreDir.path, 'localization_helper.dart'));
    if (!await helperFile.exists()) {
      const helperContent = '''import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// Global navigator key allowing context-less localization lookups.
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

/// Optional override locale if the developer sets MaterialApp(locale: ...) manually
Locale? _overrideLocale;
void setAutoLocalizeLocale(Locale? locale) => _overrideLocale = locale;

/// Context-less global getter for localized application strings.
AppLocalizations get l10n {
  final context = globalNavigatorKey.currentContext;
  if (context != null) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      return localizations;
    }
  }

  // Safe fallback before NavigatorState is mounted (e.g., inside MaterialApp.title)
  final targetLocale = _overrideLocale ?? ui.PlatformDispatcher.instance.locale;
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == targetLocale.languageCode) {
      return lookupAppLocalizations(supported);
    }
  }
  return lookupAppLocalizations(AppLocalizations.supportedLocales.first);
}
''';
      await helperFile.writeAsString(helperContent);
    }
  }

  /// Creates lib/core/app_strings.dart for central error and string definitions.
  Future<void> _createAppStrings() async {
    final coreDir = Directory(p.join(projectDir.path, 'lib', 'core'));
    await coreDir.create(recursive: true);

    final appStringsFile = File(p.join(coreDir.path, 'app_strings.dart'));
    if (!await appStringsFile.exists()) {
      const content = '''import 'localization_helper.dart';

/// Central class for application strings and messages.
class AppStrings {
  AppStrings._();
}
''';
      await appStringsFile.writeAsString(content);
    }
  }
}
