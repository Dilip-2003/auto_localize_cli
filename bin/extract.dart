import 'auto_localize_cli.dart' as cli;

Future<void> main(List<String> arguments) async {
  await cli.main(['extract', ...arguments]);
}
