import 'dart:ui';
import 'package:flutter/widgets.dart';
import '../../l10n/generated/app_localizations.dart';

/// Global key to access the root navigator state from anywhere.
GlobalKey<NavigatorState> _globalNavigatorKey = GlobalKey<NavigatorState>();

/// Returns the active [GlobalKey] used by the root navigator.
GlobalKey<NavigatorState> get globalNavigatorKey => _globalNavigatorKey;

/// Sets a custom [GlobalKey] if your app already defines its own rootNavigatorKey.
void setGlobalNavigatorKey(GlobalKey<NavigatorState> key) {
  _globalNavigatorKey = key;
}

/// Listenable that notifies listeners when the app locale changes at runtime.
final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);

/// Programmatically updates the application language at runtime without app restart.
void changeAppLocale(Locale locale) {
  localeNotifier.value = locale;
}

/// Global context-less accessor for [AppLocalizations].
///
/// Can be accessed anywhere (UI, BLoCs, Repositories, Interceptors) without BuildContext!
AppLocalizations get l10n {
  final context = _globalNavigatorKey.currentContext;
  if (context != null) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      return localizations;
    }
  }

  // Pre-mount fallback if accessed before NavigatorState context is ready
  final locale = localeNotifier.value ??
      PlatformDispatcher.instance.locales.firstOrNull ??
      const Locale('en');
  return lookupAppLocalizations(locale);
}
