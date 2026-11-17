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
    )
    ..addOption(
      'file',
      abbr: 'f',
      help:
          'Target a single Dart file to extract (bypasses full directory crawl).',
    )
    ..addFlag(
      'dry-run',
      abbr: 'd',
      negatable: false,
      help:
          'Preview strings to extract and files to modify without writing changes to disk.',
    )
    ..addFlag(
      'git-diff',
      abbr: 'g',
      negatable: false,
      help:
          'Extract only from modified and untracked Git files under lib/ (sub-second execution for monorepos).',
    )
    ..addFlag(
      'cache',
      defaultsTo: true,
      help:
          'Enable sharded incremental file-stat caching (use --no-cache to force full re-scan).',
    )
    ..addOption(
      'workers',
      abbr: 'w',
      help:
          'Number of parallel Isolate workers for AST parsing (defaults to CPU cores, max 8).',
    );

  final argResults = parser.parse(arguments);
  if (argResults['help'] as bool) {
    stdout.writeln('Usage: dart run auto_localize_cli:extract [options]\n');
    stdout.writeln(
      'Extracts hardcoded UI strings into ARB and updates source files.\n',
    );
    stdout.writeln(parser.usage);
    return;
  }

  final locale = argResults['locale'] as String?;
  final file = argResults['file'] as String?;
  final dryRun = argResults['dry-run'] as bool;
  final gitDiff = argResults['git-diff'] as bool;
  final noCache = !(argResults['cache'] as bool);
  final workersStr = argResults['workers'] as String?;
  final workers = workersStr != null ? int.tryParse(workersStr) : null;

  final runner = ExtractRunner(
    locale: locale,
    targetFilePath: file,
    dryRun: dryRun,
    gitDiff: gitDiff,
    noCache: noCache,
    workers: workers,
  );
  await runner.run();
}
