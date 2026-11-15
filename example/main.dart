import 'package:flutter/material.dart';
import 'lib/l10n/generated/app_localizations.dart';

// Generated automatically by `dart run auto_localize_cli:init`:
import 'lib/core/localization_helper.dart';

void main() {
  runApp(const AutoLocalizeExampleApp());
}

/// The root application widget demonstrating `auto_localize_cli`.
class AutoLocalizeExampleApp extends StatelessWidget {
  const AutoLocalizeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder enables instant runtime language switching
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          // Step 1: Pass globalNavigatorKey (enables context-less l10n everywhere)
          navigatorKey: globalNavigatorKey,
          locale: currentLocale,
          title: l10n.appTitle, // Context-less safe pre-mount getter!
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

/// The main dashboard screen showing context-less `l10n` usage.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Step 2: Use l10n.<key> directly without BuildContext
        title: Text(l10n.dashboardTitle),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.language_rounded, size: 64, color: Colors.indigo),
              const SizedBox(height: 24),

              // Parameterized string with placeholders (name, count)
              Text(
                l10n.welcomeBackUser('Alex', 3),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                l10n.selectLanguage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Step 3: Switch languages live at runtime with zero app restart!
              Wrap(
                spacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => changeAppLocale(const Locale('en')),
                    icon: const Text('🇺🇸'),
                    label: const Text('English'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => changeAppLocale(const Locale('es')),
                    icon: const Text('🇪🇸'),
                    label: const Text('Español'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Step 4: Context-less usage inside non-UI Business Logic / Repository
              OutlinedButton.icon(
                onPressed: () {
                  // Simulate an error in a BLoC or Repository without context
                  final errorMsg = AuthRepository().simulateNetworkFailure();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errorMsg)),
                  );
                },
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Test Context-less Repository Call'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Demonstrates using `l10n` in business logic without `BuildContext`.
class AuthRepository {
  String simulateNetworkFailure() {
    // Access localized strings directly inside business logic or API interceptors:
    return l10n.networkError;
  }
}
