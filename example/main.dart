import 'dart:io';
import 'package:auto_localize_cli/auto_localize_cli.dart';

/// Example demonstrating programmatically running AutoLocalize CLI runners.
///
/// In typical Flutter workflows, developers run the CLI commands from their terminal:
///
/// 1. Initialize localization scaffolding (default English):
/// ```bash
/// dart run auto_localize_cli:init
/// ```
///
/// Or initialize with a custom primary language (e.g. Russian, Spanish, French, Bengali):
/// ```bash
/// dart run auto_localize_cli:init --locale ru
/// ```
///
/// 2. Extract hardcoded UI strings and rewrite source code:
/// ```bash
/// dart run auto_localize_cli:extract
/// ```
void main() async {
  final currentDirectory = Directory.current;

  // Step 1: Initialize localization setup with default or custom locale (e.g. 'en', 'ru', 'es')
  final initRunner = InitRunner(
    projectDir: currentDirectory,
    defaultLocale: 'en',
  );
  await initRunner.run();

  // Step 2: Extract hardcoded strings and rewrite Dart source files bottom-to-top
  final extractRunner = ExtractRunner(
    projectDir: currentDirectory,
  );
  await extractRunner.run();
}
