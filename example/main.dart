import 'dart:io';
import 'package:auto_localize_cli/auto_localize_cli.dart';

/// Example demonstrating programmatically running AutoLocalize CLI runners.
///
/// In typical Flutter workflows, developers run the CLI commands from their terminal:
///
/// 1. Initialize localization scaffolding:
/// ```bash
/// dart run auto_localize_cli:init
/// ```
///
/// 2. Extract hardcoded UI strings and rewrite source code:
/// ```bash
/// dart run auto_localize_cli:extract
/// ```
void main() async {
  final currentDirectory = Directory.current;

  // Step 1: Initialize localization setup
  final initRunner = InitRunner(projectDir: currentDirectory);
  await initRunner.run();

  // Step 2: Extract strings and rewrite Dart files
  final extractRunner = ExtractRunner(projectDir: currentDirectory);
  await extractRunner.run();
}
