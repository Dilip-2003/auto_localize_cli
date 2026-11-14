import 'dart:io';
import 'package:args/args.dart';
import 'package:auto_localize_cli/auto_localize_cli.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show command usage instructions.',
    )
    ..addOption(
      'locale',
      abbr: 'l',
      help:
          'Target locale template ARB file to extract into (e.g. en, ru, es, bn). If omitted, automatically detected from l10n.yaml.',
    );

  final argResults = parser.parse(arguments);
  if (argResults['help'] as bool) {
    stdout.writeln('Usage: dart run auto_localize_cli:extract [options]\n');
    stdout.writeln(
        'Extracts hardcoded UI strings into ARB and updates source files.\n');
    stdout.writeln(parser.usage);
    return;
  }

  final locale = argResults['locale'] as String?;
  final runner = ExtractRunner(locale: locale);
  await runner.run();
}
