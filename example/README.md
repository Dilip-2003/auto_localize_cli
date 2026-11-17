# auto_localize_cli Example & Integration Guide

Welcome to the **`auto_localize_cli`** example showcase! This guide demonstrates how to configure, run, and take full advantage of context-less localization in your Flutter applications.

---

## ⚡ The 3-Step Workflow

```
┌─────────────────────────────────┐
│ 1. dart pub add dev:...         │ ➔ Adds auto_localize_cli to dev_dependencies
└─────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│ 2. dart run auto_localize_cli init  ➔ Scaffolds l10n.yaml, template ARB, and
└─────────────────────────────────┘    lib/core/localization/localization_helper.dart
                │
                ▼
┌─────────────────────────────────┐
│ 3. dart run auto_localize_cli extract ➔ Parses Dart AST, extracts strings to ARB,
└─────────────────────────────────┘    removes consts, and rewrites to l10n.key!
```

---

## 🔍 Before & After Showcase

### 1. Plain Hardcoded Widget (Before)
```dart
// Your original Flutter widget with hardcoded strings and const trees
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('Welcome Back!'),
        Text('Manage your account settings and preferences'),
      ],
    );
  }
}
```

### 2. After Running `dart run auto_localize_cli extract`
```dart
// Generated and updated automatically by auto_localize_cli
import 'package:my_app/core/localization/localization_helper.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Ancestor `const` was automatically removed from Column
    // 2. Strings were extracted into lib/l10n/app_en.arb
    // 3. Replaced with compile-safe, context-less l10n getters!
    return Column(
      children: [
        Text(l10n.welcomeBack),
        Text(l10n.manageYourAccountSettingsAndPreferences),
      ],
    );
  }
}
```

---

## 📱 Complete Working Flutter Application Example

Here is a complete, copy-pasteable `main.dart` showing:
- Passing `globalNavigatorKey` into `MaterialApp`.
- Live runtime language switching via `localeNotifier` and `changeAppLocale`.
- Calling `l10n` from both the UI layer and business logic (without `BuildContext`).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 1. Import localization_helper.dart (generated automatically by `init`)
import 'package:my_app/core/localization/localization_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder enables live language switching on the fly!
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          // Pass the global navigator key generated in lib/core/localization/localization_helper.dart
          navigatorKey: globalNavigatorKey,
          locale: currentLocale,
          title: l10n.myAppTitle, // Pre-mount safe fallback!
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeDashboard),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Parameterized string with placeholders (e.g. "Welcome back {name}")
            Text(
              l10n.welcomeBackUser('Alex'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(l10n.selectYourPreferredLanguage),
            const SizedBox(height: 24),

            // Live language switcher buttons:
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => changeAppLocale(const Locale('en')),
                  child: const Text('English 🇺🇸'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => changeAppLocale(const Locale('es')),
                  child: const Text('Español 🇪🇸'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => changeAppLocale(const Locale('bn')),
                  child: const Text('বাংলা 🇧🇩'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 💡 Real-World Production Recipes

### Recipe 1: Context-less Translations inside BLoC / Cubit
Never pass `BuildContext` into your state management layer again:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/core/localization/localization_helper.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      await authRepository.authenticate(email, password);
      emit(AuthSuccess());
    } catch (e) {
      // Access localized error strings without needing BuildContext!
      emit(AuthError(l10n.invalidCredentialsPleaseTryAgain));
    }
  }
}
```

---

### Recipe 2: Context-less Translations inside Repositories or Dio Interceptors
Display localized error notifications directly from HTTP or network interceptors:

```dart
import 'package:dio/dio.dart';
import 'package:my_app/core/localization/localization_helper.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String userMessage;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        userMessage = l10n.connectionTimeoutMessage;
        break;
      case DioExceptionType.badResponse:
        userMessage = l10n.serverErrorMessage;
        break;
      default:
        userMessage = l10n.unexpectedErrorOccurred;
    }

    // Access current overlay or scaffold messenger via globalNavigatorKey:
    final context = globalNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessage)),
      );
    }

    super.onError(err, handler);
  }
}
```

---

### Recipe 3: Declarative Routing with `GoRouter`
Using `GoRouter`? Simply wire `globalNavigatorKey` into the router configuration:

```dart
import 'package:go_router/go_router.dart';
import 'package:my_app/core/localization/localization_helper.dart';

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

### Recipe 4: Existing Project with an Established `rootNavigatorKey`
If your Flutter application already defines an existing navigation key:

```dart
import 'package:my_app/core/localization/localization_helper.dart';
import 'package:my_app/routes/app_router.dart'; // Where your existing rootNavigatorKey lives

void main() {
  // Register your existing rootNavigatorKey with auto_localize:
  setGlobalNavigatorKey(rootNavigatorKey);
  runApp(const MyApp());
}
```

---

### Recipe 5: Adding More Languages in 2 Minutes (AI Translation Workflow)

Once `auto_localize_cli extract` compiles all hardcoded strings into `lib/l10n/app_en.arb`, adding any new language is as simple as:

1. **Copy `app_en.arb`** and paste it into ChatGPT, Claude, or Gemini:
   > *"Translate this Flutter ARB file into Spanish (`es`). Keep all JSON keys and `{placeholder}` tokens unchanged."*
2. **Save the response** as `lib/l10n/app_es.arb` (or `app_bn.arb`, `app_ar.arb`, etc.).
3. **Run recompilation:**
   ```bash
   flutter gen-l10n
   ```
4. **Switch language on the fly:**
   ```dart
   changeAppLocale(const Locale('es'));
   ```

No widget rewrites, no manual `.tr` extensions, and zero `BuildContext` boilerplate!

---

## 🛠️ CLI Terminal Cheat Sheet

| Task | Terminal Command |
|---|---|
| **Add CLI Dependency** | `flutter pub add dev:auto_localize_cli` |
| **Initialize Scaffolding (English)** | `dart run auto_localize_cli init` |
| **Initialize Custom Base Language** | `dart run auto_localize_cli init -l es` *(or `-l ru`, `-l bn`)* |
| **Extract All Hardcoded Strings** | `dart run auto_localize_cli extract` |
| **Sub-Second Git-Diff Mode** | `dart run auto_localize_cli extract --git-diff` *(or `-g`)* |
| **Single-File Targeted Extraction** | `dart run auto_localize_cli extract --file <path>` *(or `-f`)* |
| **Dry-Run Preview Mode** | `dart run auto_localize_cli extract --dry-run` *(or `-d`)* |
| **Bypass Incremental Cache** | `dart run auto_localize_cli extract --no-cache` |
| **Configure Worker Threads** | `dart run auto_localize_cli extract -w 4` |
| **Manual Recompilation** | `flutter gen-l10n` |
