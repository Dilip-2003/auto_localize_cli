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
    );

  final argResults = parser.parse(arguments);
  if (argResults['help'] as bool) {
    stdout.writeln('Usage: dart run auto_localize_cli:init [options]\n');
    stdout.writeln('Scaffolds localization configs, ARB templates, and context-less getter.\n');
    stdout.writeln(parser.usage);
    return;
  }

  final runner = InitRunner();
  await runner.run();
}
