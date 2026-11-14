# auto_localize_cli Example

This directory demonstrates how `auto_localize_cli` is initialized, executed, and integrated into Flutter applications.

## Terminal Quick Start

In your Flutter project root:

```bash
# 1. Add to dev_dependencies
flutter pub add dev:auto_localize_cli

# 2. Initialize localization scaffolding (English default)
dart run auto_localize_cli:init

# Or initialize with your preferred base language (e.g. Russian, Spanish, French, Bengali)
dart run auto_localize_cli:init --locale ru
dart run auto_localize_cli:init -l es

# 2. Extract strings into .arb and update source files bottom-to-top
dart run auto_localize_cli:extract

# 3. Sub-second extraction for changed files in Git (Recommended for everyday coding):
dart run auto_localize_cli:extract --git-diff
dart run auto_localize_cli:extract -g

# 4. Force full re-scan bypassing incremental cache:
dart run auto_localize_cli:extract --no-cache

# 5. Parallel isolate workers:
dart run auto_localize_cli:extract --workers 8
dart run auto_localize_cli:extract -w 4
```

---

## Complete CLI Command Reference

### `dart run auto_localize_cli:init`
Scaffolds `l10n.yaml`, template ARB, and `lib/core/` helper files.
- `--locale`, `-l <code >`: Sets base language (e.g. `-l ru`, `-l es`, `-l bn`). Defaults to `en`.

### `dart run auto_localize_cli:extract`
Extracts hardcoded strings into ARB and rewrites source code with `l10n.<key>`.
- `--git-diff`, `-g`: Extracts only from modified/untracked Git files ($O(k)$ sub-second time).
- `--no-cache`: Forces a complete re-scan, bypassing the incremental file-stat cache.
- `--workers`, `-w <int>`: Configures parallel worker Isolates (defaults to CPU cores, max 8).
- `--locale`, `-l <code >`: Targets a specific ARB template file (e.g. `-l es`).

---

## Integration Scenarios

### 1. Standard `MaterialApp` Integration

```dart
import 'package:flutter/material.dart';

// 1. Import localization_helper.dart (generated automatically by `init`)
import 'package:your_app_name/core/localization_helper.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier, // Live dynamic language switching
      builder: (context, currentLocale, _) {
        return MaterialApp(
          navigatorKey: globalNavigatorKey, // <-- Pass key from localization_helper.dart
          locale: currentLocale,
          title: l10n.testApp, // <-- Safe pre-mount fallback!
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        );
      },
    );
  }
}
```

---

### 2. `GoRouter` Setup with `globalNavigatorKey`

When using declarative routers like `GoRouter`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 1. Import localization_helper.dart
import 'package:your_app_name/core/localization_helper.dart';

final goRouter = GoRouter(
  navigatorKey: globalNavigatorKey, // <-- Wire GoRouter directly to globalNavigatorKey
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: goRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
```

---

### 3. Projects with an Existing `rootNavigatorKey`

If your Flutter application already defines an existing `rootNavigatorKey` (e.g. in `lib/routes/app_router.dart`), you have three seamless options:

#### Option A: Register your existing key via `setGlobalNavigatorKey` (Recommended)
```dart
import 'package:your_app_name/core/localization_helper.dart';
import 'package:your_app_name/routes/app_router.dart'; // Where rootNavigatorKey is defined

void main() {
  // Register your existing rootNavigatorKey with auto_localize
  setGlobalNavigatorKey(rootNavigatorKey);
  runApp(const MyApp());
}
```

#### Option B: Alias your existing key inside `lib/core/localization_helper.dart`
Open `lib/core/localization_helper.dart` and point `globalNavigatorKey` directly to your existing key:
```dart
import 'package:your_app_name/routes/app_router.dart';

// Point globalNavigatorKey to your existing rootNavigatorKey
final GlobalKey<NavigatorState> globalNavigatorKey = rootNavigatorKey;
```

#### Option C: Wire `globalNavigatorKey` into your existing router
Replace `final rootNavigatorKey = GlobalKey<NavigatorState>();` in your router file with:
```dart
import 'package:your_app_name/core/localization_helper.dart';

final rootNavigatorKey = globalNavigatorKey;
```

For complete architectural documentation, see the [main README](../README.md).
