/// # auto_localize_cli
///
/// An AST-powered Flutter CLI that eliminates manual `.arb` copy-pasting,
/// removes ancestor `const` compile errors, and enables context-less `l10n.<key>`
/// access everywhere.
///
/// ## ⚡ CLI Workflow & Logic
///
/// `auto_localize_cli` is primarily executed via the command line:
///
/// ### 1. Initialization Command
/// ```bash
/// dart run auto_localize_cli:init
/// ```
/// **Logic & Execution:**
/// - Injects `flutter_localizations` & `intl` into your `pubspec.yaml` with `generate: true`.
/// - Scaffolds `l10n.yaml` targeting `lib/l10n`.
/// - Creates your base template ARB file (`lib/l10n/app_en.arb`).
/// - Scaffolds `lib/core/localization/localization_helper.dart` providing `globalNavigatorKey`,
///   the pre-mount safe context-less getter `l10n`, and reactive locale switcher `changeAppLocale`.
/// - Scaffolds `lib/core/localization/app_strings.dart` for non-UI messages.
///
/// ### 2. One-Time MaterialApp Setup
/// In your `lib/main.dart`:
/// ```dart
/// import 'package:your_app/core/localization/localization_helper.dart';
///
/// MaterialApp(
///   navigatorKey: globalNavigatorKey, // <-- Enables context-less l10n everywhere!
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: const HomeScreen(),
/// )
/// ```
///
/// ### 3. Extraction Command
/// ```bash
/// dart run auto_localize_cli:extract
/// ```
/// **Logic & Execution:**
/// - Uses Dart's `analyzer` AST visitor to scan all Dart files for hardcoded strings.
/// - Generates smart, human-readable camelCase keys and appends them non-destructively to `lib/l10n/app_en.arb`.
/// - Walks up AST ancestor chains to detect and delete enclosing `const` tokens.
/// - Rewrites `Text('Hello World')` into `Text(l10n.helloWorld)`.
/// - Automatically runs `flutter gen-l10n` to compile Dart localization classes.
library auto_localize_cli;

export 'src/analyzer/ast_payload.dart';
export 'src/analyzer/ast_visitor.dart';
export 'src/analyzer/cache_manager.dart';
export 'src/analyzer/code_rewriter.dart';
export 'src/analyzer/directory_crawler.dart';
export 'src/analyzer/extract_runner.dart';
export 'src/analyzer/pre_ast_filter.dart';
export 'src/generator/arb_manager.dart';
export 'src/generator/key_generator.dart';
export 'src/setup/init_runner.dart';
