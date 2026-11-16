import 'localization_helper.dart';

/// Central class for application strings and messages.
///
/// Use this class to define centralized non-UI and business logic strings.
class AppStrings {
  AppStrings._();

  /// Example static getter connected to the context-less `l10n` getter.
  static String get networkError => l10n.networkError;
}
