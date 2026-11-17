import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:auto_localize_cli/auto_localize_cli.dart';

const String packageVersion = '1.0.7';

class InitCommand extends Command<void> {
  @override
  final String name = 'init';
  @override
  final String description =
      'Scaffolds localization configs, ARB templates, and context-less getter.';

  InitCommand() {
    argParser.addOption(
      'locale',
      abbr: 'l',
      defaultsTo: 'en',
      help:
          'Default base locale (e.g. en, ru, es, bn, fr, de). Defaults to "en".',
    );
  }

  @override
  Future<void> run() async {
    final defaultLocale = argResults?['locale'] as String? ?? 'en';
    final runner = InitRunner(defaultLocale: defaultLocale);
    await runner.run();
  }
}

class ExtractCommand extends Command<void> {
  @override
  final String name = 'extract';
  @override
  final String description =
      'Extracts hardcoded UI strings into ARB and updates source files.';

  ExtractCommand() {
    argParser
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
  }

  @override
  Future<void> run() async {
    final results = argResults!;
    final locale = results['locale'] as String?;
    final file = results['file'] as String?;
    final dryRun = results['dry-run'] as bool;
    final gitDiff = results['git-diff'] as bool;
    final noCache = !(results['cache'] as bool);
    final workersStr = results['workers'] as String?;
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
}

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<void>(
    'auto_localize_cli',
    'AST-powered Flutter CLI for automated hardcoded string extraction and localization.',
  )
    ..addCommand(InitCommand())
    ..addCommand(ExtractCommand());

  runner.argParser.addFlag(
    'version',
    abbr: 'v',
    negatable: false,
    help: 'Print the current CLI version.',
  );

  try {
    if (arguments.contains('--version') || arguments.contains('-v')) {
      stdout.writeln('auto_localize_cli version: $packageVersion');
      return;
    }

    if (arguments.isEmpty) {
      runner.printUsage();
      return;
    }

    await runner.run(arguments);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln('');
    stderr.writeln(e.usage);
    exitCode = 64; // EX_USAGE
  } catch (e, stack) {
    stderr.writeln('An unexpected error occurred: $e');
    stderr.writeln(stack);
    exitCode = 1;
  }
}
