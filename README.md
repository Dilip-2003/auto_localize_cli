# auto_localize_cli

<p align="center">
  <img src="https://raw.githubusercontent.com/Dilip-2003/auto_localize_cli/main/assets/banner.png" alt="auto_localize_cli banner" width="100%"/>
</p>

<p align="center">
  <strong>⚡ Zero-config AST-powered Flutter CLI that automatically extracts hardcoded strings into .arb files, removes ancestor const modifiers, and rewrites source code to use a context-less, compile-safe l10n getter.</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/auto_localize_cli"><img src="https://img.shields.io/pub/v/auto_localize_cli.svg?style=flat-square" alt="pub version"/></a>
  <a href="https://pub.dev/packages/auto_localize_cli"><img src="https://img.shields.io/pub/points/auto_localize_cli?style=flat-square" alt="pub points"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License: MIT"/></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Platform-Flutter%20%7C%20Dart-02569B.svg?style=flat-square" alt="Platform"/></a>
</p>

---

## 🎯 Why auto_localize_cli?

Localizing a Flutter application is traditionally a slow, error-prone manual process:
1. Scanning tens or hundreds of files to hunt down hardcoded string literals.
2. Manually inventing unique `camelCase` keys and copying them into `.arb` files.
3. Breaking parent `const` trees across your widget tree and fixing resulting compile errors.
4. Passing `BuildContext` deep into controllers, repositories, and BLoCs just to access localized error messages.

**`auto_localize_cli` automates this entire lifecycle via the Dart Analyzer AST:**
- Extracts hardcoded UI strings and interpolations into your template `.arb` file.
- Generates clean, semantic, collision-free `camelCase` keys automatically.
- Automatically removes enclosing `const` tokens up the widget tree so your code compiles immediately.
- Rewrites widgets to use a clean, context-less global getter: `l10n.<key>`.
- Preserves 100% of your existing translations, comments, and project structure non-destructively.
- Adds **0 KB** to your release bundle (pure `dev_dependencies` tool).

---

## ⚡ Quick Start (5 Simple Steps)

### Step 1: Install
Add `auto_localize_cli` to your project's `dev_dependencies`:

```bash
flutter pub add dev:auto_localize_cli
```

Or activate globally to use the CLI from anywhere:

```bash
dart pub global activate auto_localize_cli
```

---

### Step 2: Initialize
Scaffold your localization architecture with one command:

```bash
dart run auto_localize_cli init
# Or if globally activated:
auto_localize_cli init
```
*(Optional: specify a custom base language: `-l es`, `-l ru`, `-l bn`)*

**What `init` sets up:**
- Configures `pubspec.yaml` with `flutter_localizations`, `intl`, and `flutter: generate: true`.
- Generates standard `l10n.yaml` settings.
- Creates `lib/l10n/app_en.arb` template.
- Scaffolds `lib/core/localization/localization_helper.dart` (providing `globalNavigatorKey`, context-less `l10n`, and reactive `changeAppLocale`).
- Scaffolds `lib/core/localization/app_strings.dart` (an optional central catalog for non-UI domain errors, failure messages, and business constants).
- **Automatically runs `flutter pub get` & `flutter gen-l10n`** so all localization classes are generated immediately with zero IDE errors.

---

### Step 3: Connect `MaterialApp` (One-Time Setup)
In your `lib/main.dart`, wrap with `ValueListenableBuilder<Locale?>` and pass `globalNavigatorKey`:

```dart
import 'package:flutter/material.dart';
import 'package:your_app/core/localization/localization_helper.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier, // Enables live runtime language switching
      builder: (context, currentLocale, _) {
        return MaterialApp(
          navigatorKey: globalNavigatorKey, // <-- Enables context-less l10n everywhere!
          locale: currentLocale,
          title: l10n.appTitle, // Safe pre-mount fallback!
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        );
      },
    );
  }
}
```

> **Using GoRouter or declarative routing?**
> Pass `globalNavigatorKey` into your `GoRouter` instance:
> ```dart
> final router = GoRouter(
>   navigatorKey: globalNavigatorKey, // <-- Pass globalNavigatorKey here
>   routes: [...],
> );
> 
> MaterialApp.router(
>   routerConfig: router,
>   locale: currentLocale,
>   localizationsDelegates: AppLocalizations.localizationsDelegates,
>   supportedLocales: AppLocalizations.supportedLocales,
> );
> ```

---

### Step 4: Extract All Hardcoded Strings
Write your Flutter widgets naturally with plain strings. When ready, run:

```bash
dart run auto_localize_cli extract
# Or if globally activated:
auto_localize_cli extract
```

#### Before & After Transformation:

**Before:**
```dart
class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('Welcome Back!'),
        Text('Manage your account settings'),
      ],
    );
  }
}
```

**After Running `extract`:**
```dart
import 'package:your_app/core/localization/localization_helper.dart';

class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Column( // <-- const automatically removed from parent!
      children: [
        Text(l10n.welcomeBack),
        Text(l10n.manageYourAccountSettings),
      ],
    );
  }
}
```

**Generated `lib/l10n/app_en.arb`:**
```json
{
  "@@locale": "en",
  "welcomeBack": "Welcome Back!",
  "manageYourAccountSettings": "Manage your account settings"
}
```

---

### Step 5: Add Other Languages in 2 Minutes (AI Workflow)
1. Copy `lib/l10n/app_en.arb` into ChatGPT, Claude, or Gemini:  
   > *"Translate this Flutter .arb file into Spanish (`es`). Keep all keys and `{placeholder}` tokens intact."*
2. Save the output as `lib/l10n/app_es.arb`.
3. Run `flutter gen-l10n`.
4. Switch language live anywhere in your app:
   ```dart
   changeAppLocale(const Locale('es'));
   ```

---

## 🏛️ Architectural Rule: UI Strings vs Business Logic Strings

`auto_localize_cli` enforces a clean, robust separation of concerns to guarantee zero broken builds across your codebase:

| Layer | Examples | How It Works |
|---|---|---|
| **🎨 UI Layer (Widgets)** | `Text('Hello')`, `title: 'Welcome'`, `showSnackBar('Saved')` | **Automatically extracted.** The AST visitor scans the widget tree bottom-up, extracts hardcoded literals into `.arb`, removes parent `const` keywords, and rewrites calls to `l10n.<key>`. |
| **⚙️ Business & Service Layers** | Custom domain models (`OemConfig(step1Highlight: '...')`), Repositories, BLoCs | **Centralized via `AppStrings`.** Hardcoded strings in services or custom classes are safely ignored by the CLI to prevent broken builds or compile errors. |

### Why does the CLI safely ignore hardcoded strings in services & custom models?
1. **Zero Broken Builds:** Custom service classes and domain models (e.g. `OemConfig(step1Highlight: '...')` or `enum Trigger { power(...) }`) use custom constructor parameters or compile-time constants. Guessing arbitrary parameter names in non-UI classes can corrupt business logic or break Dart's `const` rules.
2. **Clean Separation of Concerns:** In Clean Architecture, services should communicate with platform channels or data sources—not store hardcoded English copy directly inside business logic.

### How to localize non-UI strings cleanly with `AppStrings`:
Whenever you have instructional copy, error messages, or domain constants in non-UI code, simply define them in `lib/core/localization/app_strings.dart`:

```dart
class AppStrings {
  AppStrings._();

  static const String autostartHint = 'Open Settings › Apps › Kokua';
  static const String networkTimeout = 'Connection timed out. Please check your internet.';
}
```

When you run `auto_localize_cli extract`, the CLI automatically detects `AppStrings` (and classes ending in `*Strings`, `*Errors`, `*Messages`, or `*Constants`), extracts the strings into your template `.arb` catalog, and rewrites them into live, context-less getters:

```dart
import 'localization_helper.dart';

class AppStrings {
  AppStrings._();

  static String get autostartHint => l10n.openSettingsAppsKokua;
  static String get networkTimeout => l10n.connectionTimedOutPlease;
}
```

Now your services, repositories, or BLoCs can access localized text cleanly without needing `BuildContext`:
```dart
// Inside your service or domain model:
OemAutostartConfig(step1Hint: AppStrings.autostartHint);

// Inside your API repository or BLoC:
throw ServerException(AppStrings.networkTimeout);
```

---

## 🛠️ CLI Command Reference

### 1. `init`
Initializes localization dependencies, templates, and helpers. Non-destructive; never overwrites existing `.arb` files or custom configs.

```bash
dart run auto_localize_cli init [options]
# or: auto_localize_cli init [options]
```

| Option | Shorthand | Default | Description |
|:---|:---:|:---:|:---|
| `--locale` | `-l` | `'en'` | Base locale code (e.g. `en`, `es`, `bn`, `fr`, `de`). |
| `--help` | `-h` | | Show command help. |

---

### 2. `extract`
Scans Dart files, extracts strings to `.arb`, strips ancestor `const`, and rewrites source files.

```bash
dart run auto_localize_cli extract [options]
# or: auto_localize_cli extract [options]
```

| Option | Shorthand | Default | Description |
|:---|:---:|:---:|:---|
| `--git-diff` | `-g` | `false` | **Sub-second $O(k)$ extraction.** Scans only Git-modified and untracked files under `lib/`. Perfect for everyday coding and Git hooks. |
| `--file` | `-f` | `null` | Target a single Dart file (e.g. `-f lib/features/home/home_screen.dart`). |
| `--dry-run` | `-d` | `false` | Preview extracted strings and modified files without writing changes to disk or ARB. |
| `--no-cache` | | `false` | Force full re-scan, bypassing incremental sharded cache. |
| `--workers` | `-w` | CPU cores (max 8) | Number of parallel worker isolates for AST parsing. |
| `--locale` | `-l` | Auto-detected | Specific target ARB file to extract into. Defaults to template in `l10n.yaml`. |
| `--help` | `-h` | | Show command help. |

---

### 🎯 Practical Use Cases & Shorthand Cheat Sheet

Don't run a full codebase scan every time! Use these shorthands designed for common everyday workflows:

#### 1. Test On A Single File First (`-f`)
Adopting `auto_localize_cli` on an existing production app? Start small and safe by testing on one specific screen or widget without touching the rest of your codebase:
```bash
auto_localize_cli extract -f lib/features/home/home_screen.dart
```

#### 2. Preview Changes With Zero Risk (`-d` / `--dry-run`)
Want to verify which strings will be extracted and see exactly which files will be modified before anything is written to disk or ARB?
```bash
# Dry run across the entire project:
auto_localize_cli extract -d

# Or combine with a single file to inspect only that file:
auto_localize_cli extract -f lib/screens/login_view.dart -d
```

#### 3. Everyday Coding & Git Pre-Commit Hooks (`-g` / `--git-diff`)
While developing a feature, you only care about files you recently touched. The `-g` flag runs a **sub-second $O(k)$ extraction** scanning *only* Git-staged, modified, or newly created files:
```bash
# Instant extraction on your active work:
auto_localize_cli extract -g
```
> **Pro Tip:** Add `auto_localize_cli extract -g` to your Git pre-commit hook to automatically localize new strings before every commit!

#### 4. Target A Custom Base Language (`-l`)
If your primary app language is Spanish (`es`), French (`fr`), or Bengali (`bn`):
```bash
auto_localize_cli extract -l es
```

#### 5. Hyper-Scale Enterprise Repositories (`-w` & `--no-cache`)
For massive monorepos or enterprise codebases (thousands of Dart files):
```bash
# Maximize CPU isolate concurrency with 8 parallel workers:
auto_localize_cli extract -w 8

# Force a 100% clean rebuild bypassing incremental file-stat cache:
auto_localize_cli extract --no-cache
```

---

## 🧩 Advanced Features & Architecture

### 1. Context-Less `l10n` Anywhere
Because `l10n` is backed by `globalNavigatorKey`, you can access localized strings from non-UI layers without passing `BuildContext`:

```dart
// Inside a BLoC, Cubit, or Repository:
import 'package:your_app/core/localization/localization_helper.dart';

class AuthRepository {
  Future<void> login(String email, String password) async {
    try {
      await api.login(email, password);
    } catch (e) {
      throw Exception(l10n.invalidCredentialsError);
    }
  }
}
```

### 2. Pre-Mount Safe Fallback
When initializing `MaterialApp(title: l10n.appTitle)`, the `title` property is evaluated before `NavigatorState` is mounted. Instead of crashing, `l10n` safely falls back to `lookupAppLocalizations(targetLocale)` with multi-stage language and script matching (e.g. `zh_Hant` vs `zh_Hans`).

### 3. Existing `rootNavigatorKey` or `GoRouter` Support
If your app already has an existing navigation key (e.g. with `GoRouter` or custom routing), simply register it:

```dart
// Option A: In main()
void main() {
  setGlobalNavigatorKey(yourExistingRouterKey);
  runApp(const MyApp());
}

// Option B: Pass globalNavigatorKey directly to GoRouter
final goRouter = GoRouter(
  navigatorKey: globalNavigatorKey,
  routes: [...],
);
```

### 4. String Interpolation & ICU Placeholders
Strings containing `$variables` or `${expressions}` are automatically converted to parameterized ICU messages:

**Source Widget:**
```dart
Text('Welcome back $name, you have ${items.length} unread messages')
```

**Generated Code:**
```dart
Text(l10n.welcomeBackNameUnreadMessages(name, items.length))
```

**Generated ARB:**
```json
{
  "welcomeBackNameUnreadMessages": "Welcome back {name}, you have {itemsLength} unread messages",
  "@welcomeBackNameUnreadMessages": {
    "placeholders": {
      "name": {},
      "itemsLength": {}
    }
  }
}
```

### 5. Centralized Business & Error Strings (`AppStrings`)

In Flutter apps following Clean Architecture (BLoC, Cubits, Repositories, Domain models), error messages and failure descriptions (e.g. `ServerException`, `AuthFailure`, `ValidationException`) are often generated in non-UI data layers where `BuildContext` is completely unavailable.

`auto_localize_cli` scaffolds `lib/core/localization/app_strings.dart` as an optional, clean home for these constants:

#### How It Works:
1. **Define raw constants naturally** in `lib/core/localization/app_strings.dart`:
```dart
class AppStrings {
  AppStrings._();

  static const String networkTimeout = 'Connection timed out. Please check your internet.';
  static const String invalidCredentials = 'The email or password you entered is incorrect.';
  static const String paymentFailed = 'Payment could not be processed.';
}
```

2. **Run extraction**:
```bash
auto_localize_cli extract
```

3. **Automatic transformation**:  
The CLI extracts each string into your template `.arb` catalog and rewrites the constants into clean, context-less getters backed by `l10n`:
```dart
import 'localization_helper.dart';

class AppStrings {
  AppStrings._();

  static String get networkTimeout => l10n.connectionTimedOutPlease;
  static String get invalidCredentials => l10n.theEmailOrPassword;
  static String get paymentFailed => l10n.paymentCouldNotBeProcessed;
}
```

4. **Use anywhere without `BuildContext`**:
```dart
// In a repository, BLoC, or interceptor:
throw ServerException(AppStrings.networkTimeout);
```

> **Note:** Using `AppStrings` is **100% optional**. You can also access `l10n.<key>` directly in your repositories or controllers (`throw ServerException(l10n.networkTimeout);`). `AppStrings` is provided for teams that prefer keeping all domain and error messages centralized.

---

### 6. Smart Non-UI Class & Parameter Filtering
The CLI extracts from:
- Positional argument of: `Text`, `SelectableText`, `Tooltip`, `showToast`, `showSnackBar`, `showDialog`, `showAlert`.
- 21 named UI parameters: `labelText`, `hintText`, `helperText`, `errorText`, `prefixText`, `suffixText`, `counterText`, `tooltip`, `semanticsLabel`, `title`, `subtitle`, `message`, `text`, `label`, `header`, `content`, `confirmText`, `cancelText`, `buttonText`, `action`, `prompt`.
- String getters and fields inside `lib/core/localization/app_strings.dart`.

**Strictly Ignored:**
- Non-UI classes: `Exception`, `FormatException`, `Color`, `Uri`, `DateTime`, `File`, `Directory`, `Platform`, `Process`, `HttpClient`, `Logger`, and `print(...)`.
- Asset paths (`assets/...`), URLs (`https://...`), route names (`/home`), emails, pure numbers (`"2026"`, `"100%"`), and default parameter values.

---

## 💡 Best Practices: BLoC, Cubit & State Management

In Dart, an instance field initializer such as `final String title = l10n.welcome;` evaluates **only once** at instantiation time. If the user later changes the locale via `changeAppLocale(...)`, an existing state object retains its old string.

**Recommended Patterns:**
```dart
// ✅ In UI: Evaluate dynamically in build()
Text(l10n.submitButton)

// ✅ In BLoC / Cubit State: Use a dynamic getter
class AuthSuccessState {
  String get message => l10n.loginSuccess;
}

// ✅ Or emit key/enum in state and resolve in widget:
Text(state.isError ? l10n.genericError : l10n.successMessage)
```

---

## 📁 Recommended Folder Structure

```
my_flutter_app/
├── pubspec.yaml
├── l10n.yaml                     # [Configurable: supports custom arb-dir]
├── lib/
│   ├── core/
│   │   └── localization/         # [Dedicated subfolder - never clashes with other core files]
│   │       ├── localization_helper.dart
│   │       └── app_strings.dart
│   ├── l10n/
│   │   ├── app_en.arb
│   │   └── app_es.arb
│   └── main.dart
```

---

## 📦 Zero Runtime Overhead

`auto_localize_cli` is strictly a development and build-time compiler tool. It operates directly on your source code AST during development and adds **0 KB** to your final release APK, AAB, or IPA bundle size!

---

## 🤝 Contributing & Issues

Contributions, bug reports, and feature requests are welcome!  
Feel free to open an issue or pull request on [GitHub](https://github.com/Dilip-2003/auto_localize_cli).

---

## 📄 License

MIT License. Copyright (c) 2026 Dilip Sarkar.
