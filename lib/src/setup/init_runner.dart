import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Handles the initialization and scaffolding for Phase 1.
class InitRunner {
  /// The root directory of the target Flutter project.
  final Directory projectDir;

  /// The default locale to scaffold in l10n.yaml and ARB catalogs (e.g. "en", "ru", "es").
  final String defaultLocale;

  /// Creates a new [InitRunner] for [projectDir] and [defaultLocale].
  InitRunner({
    Directory? projectDir,
    this.defaultLocale = 'en',
  }) : projectDir = projectDir ?? Directory.current;

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

    stdout.writeln(
        '🌐 Scaffolding template ARB file (lib/l10n/app_$defaultLocale.arb)...');
    await _createInitialArb();

    stdout.writeln(
        '🧩 Creating context-less global getter (lib/core/localization/localization_helper.dart)...');
    await _createLocalizationHelper();

    stdout.writeln(
        '📝 Creating core string class (lib/core/localization/app_strings.dart)...');
    await _createAppStrings();

    stdout.writeln('''
======================================================================
🎉 AutoLocalize initialized successfully!
======================================================================

Next Steps:
1. Run `flutter pub get` to fetch localization dependencies.
2. In your `main.dart`, configure your MaterialApp with:

   import 'package:$packageName/core/localization/localization_helper.dart';
   import 'package:flutter_gen/gen_l10n/app_localizations.dart';

   MaterialApp(
     navigatorKey: globalNavigatorKey,
     localizationsDelegates: AppLocalizations.localizationsDelegates,
     supportedLocales: AppLocalizations.supportedLocales,
     ...
   )

3. Add hardcoded UI strings or core errors, then run:
   dart run auto_localize_cli extract
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
        'intl': '^0.19.0',
      });
    } else {
      if (!dependencies.containsKey('flutter_localizations')) {
        editor.update(
            ['dependencies', 'flutter_localizations'], {'sdk': 'flutter'});
      }
      if (!dependencies.containsKey('intl')) {
        editor.update(['dependencies', 'intl'], '^0.19.0');
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
      final content = '''arb-dir: lib/l10n
template-arb-file: app_$defaultLocale.arb
output-localization-file: app_localizations.dart
''';
      await l10nFile.writeAsString(content);
    }
  }

  /// Creates `lib/l10n/app_<locale>.arb` if not present.
  Future<void> _createInitialArb() async {
    final arbDir = Directory(p.join(projectDir.path, 'lib', 'l10n'));
    await arbDir.create(recursive: true);

    final arbFile = File(p.join(arbDir.path, 'app_$defaultLocale.arb'));
    if (!await arbFile.exists()) {
      final initialJson = '{\n  "@@locale": "$defaultLocale"\n}\n';
      await arbFile.writeAsString(initialJson);
    }
  }

  /// Creates lib/core/localization/localization_helper.dart for context-less global getter `l10n`.
  Future<void> _createLocalizationHelper() async {
    final localizationDir =
        Directory(p.join(projectDir.path, 'lib', 'core', 'localization'));
    await localizationDir.create(recursive: true);

    final helperFile =
        File(p.join(localizationDir.path, 'localization_helper.dart'));
    if (!await helperFile.exists()) {
      const helperContent = '''import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

GlobalKey<NavigatorState>? _customNavigatorKey;

/// If your project already has an existing rootNavigatorKey (e.g. from GoRouter or a custom router),
/// register it here so `l10n` accesses localization from your existing key seamlessly:
void setGlobalNavigatorKey(GlobalKey<NavigatorState> key) => _customNavigatorKey = key;

/// Live locale notifier for dynamic runtime locale switching without restart
final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);

Locale? _overrideLocale;

/// Changes the active application locale at runtime and notifies listeners.
/// Safely schedules rebuild if called during widget build phase.
void changeAppLocale(Locale? locale) {
  void apply() {
    localeNotifier.value = locale;
    _overrideLocale = locale;

    void markDirty(Element el) {
      el.markNeedsBuild();
      el.visitChildren(markDirty);
    }

    final ctx = (_customNavigatorKey?.currentContext ??
        globalNavigatorKey.currentContext) as Element?;
    if (ctx != null) {
      markDirty(ctx);
    }
  }

  final binding = WidgetsBinding.instance;
  if (binding.buildOwner?.debugBuilding ?? false) {
    binding.addPostFrameCallback((_) => apply());
  } else {
    apply();
  }
}

void setAutoLocalizeLocale(Locale? locale) => changeAppLocale(locale);

/// Resets the global localization helper state.
/// Useful in test teardown blocks to guarantee complete test isolation.
@visibleForTesting
void resetLocalizationHelperForTesting() {
  localeNotifier.value = null;
  _overrideLocale = null;
  _customNavigatorKey = null;
}

/// Context-less global getter for localized application strings.
AppLocalizations get l10n {
  final context = _customNavigatorKey?.currentContext ??
      globalNavigatorKey.currentContext;
  if (context != null) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      return localizations;
    }
  }

  // Safe fallback before NavigatorState is mounted (e.g., inside MaterialApp.title)
  final targetLocale = _overrideLocale ?? localeNotifier.value ?? ui.PlatformDispatcher.instance.locale;

  // 1. Exact match (languageCode + scriptCode + countryCode)
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == targetLocale.languageCode &&
        supported.scriptCode == targetLocale.scriptCode &&
        supported.countryCode == targetLocale.countryCode) {
      return lookupAppLocalizations(supported);
    }
  }

  // 2. Language and script match
  if (targetLocale.scriptCode != null) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == targetLocale.languageCode &&
          supported.scriptCode == targetLocale.scriptCode) {
        return lookupAppLocalizations(supported);
      }
    }
  }

  // 3. Language only fallback
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

  /// Creates lib/core/localization/app_strings.dart for central error and string definitions.
  Future<void> _createAppStrings() async {
    final localizationDir =
        Directory(p.join(projectDir.path, 'lib', 'core', 'localization'));
    await localizationDir.create(recursive: true);

    final appStringsFile =
        File(p.join(localizationDir.path, 'app_strings.dart'));
    if (!await appStringsFile.exists()) {
      const content = '''/// Central class for application strings and messages.
class AppStrings {
  AppStrings._();
}
''';
      await appStringsFile.writeAsString(content);
    }
  }
}
