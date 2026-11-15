// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AutoLocalize Demo';

  @override
  String get dashboardTitle => 'Home Dashboard';

  @override
  String welcomeBackUser(String name, int count) {
    return 'Welcome back $name, you have $count notifications';
  }

  @override
  String get selectLanguage => 'Select your preferred language:';

  @override
  String get networkError => 'Please check your internet connection';
}
