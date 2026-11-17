import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

export '../../l10n/generated/app_localizations.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

GlobalKey<NavigatorState>? _customNavigatorKey;

/// If your project already has an existing rootNavigatorKey (e.g. from GoRouter or a custom router),
/// register it here so `l10n` accesses localization from your existing key seamlessly:
void setGlobalNavigatorKey(GlobalKey<NavigatorState> key) =>
    _customNavigatorKey = key;

/// Live locale notifier for dynamic runtime locale switching without restart
final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);

Locale? _overrideLocale;

/// Changes the active application locale at runtime and notifies listeners.
/// Safely schedules rebuild if called during widget build phase.
void changeAppLocale(Locale? locale) {
  void apply() {
    localeNotifier.value = locale;
    _overrideLocale = locale;
  }

  final binding = WidgetsBinding.instance;
  if (binding.buildOwner?.debugBuilding ?? false) {
    binding.addPostFrameCallback((_) => apply());
  } else {
    apply();
  }
}

void setAutoLocalizeLocale(Locale? locale) => changeAppLocale(locale);

/// Resets the global localization helper state.
/// Useful in test teardown blocks to guarantee complete test isolation.
@visibleForTesting
void resetLocalizationHelperForTesting() {
  localeNotifier.value = null;
  _overrideLocale = null;
  _customNavigatorKey = null;
}

/// Context-less global getter for localized application strings.
AppLocalizations get l10n {
  final context =
      _customNavigatorKey?.currentContext ?? globalNavigatorKey.currentContext;
  if (context != null) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      return localizations;
    }
  }

  // Safe fallback before NavigatorState is mounted (e.g., inside MaterialApp.title)
  final targetLocale = _overrideLocale ??
      localeNotifier.value ??
      ui.PlatformDispatcher.instance.locale;

  // 1. Exact match (languageCode + scriptCode + countryCode)
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == targetLocale.languageCode &&
        supported.scriptCode == targetLocale.scriptCode &&
        supported.countryCode == targetLocale.countryCode) {
      return lookupAppLocalizations(supported);
    }
  }

  // 2. Language and script match
  if (targetLocale.scriptCode != null) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == targetLocale.languageCode &&
          supported.scriptCode == targetLocale.scriptCode) {
        return lookupAppLocalizations(supported);
      }
    }
  }

  // 3. Language only fallback
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == targetLocale.languageCode) {
      return lookupAppLocalizations(supported);
    }
  }

  return lookupAppLocalizations(AppLocalizations.supportedLocales.first);
}
