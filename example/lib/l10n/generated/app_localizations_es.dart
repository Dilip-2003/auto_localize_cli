// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Demo de AutoLocalize';

  @override
  String get dashboardTitle => 'Panel de Inicio';

  @override
  String welcomeBackUser(String name, int count) {
    return 'Bienvenido $name, tienes $count notificaciones';
  }

  @override
  String get selectLanguage => 'Selecciona tu idioma preferido:';

  @override
  String get networkError => 'Por favor revisa tu conexión a internet';
}
