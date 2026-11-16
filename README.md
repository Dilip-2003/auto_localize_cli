# auto_localize_cli

<p align="center">
  <img src="https://raw.githubusercontent.com/Dilip-2003/auto_localize_cli/main/assets/banner.png" alt="auto_localize_cli banner" width="100%"/>
</p>

<p align="center">
  <strong>⚡ Zero-config AST-powered Flutter CLI that automatically extracts hardcoded strings & interpolations into .arb files, generates smart camelCase keys, removes ancestor const modifiers, and rewrites source code to use a context-less, compile-safe l10n getter.</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/auto_localize_cli"><img src="https://img.shields.io/pub/v/auto_localize_cli.svg?style=flat-square" alt="pub version"/></a>
  <a href="https://pub.dev/packages/auto_localize_cli"><img src="https://img.shields.io/pub/points/auto_localize_cli?style=flat-square" alt="pub points"/></a>
  <a href="https://github.com/Dilip-2003/auto_localize_cli/actions"><img src="https://img.shields.io/github/actions/workflow/status/Dilip-2003/auto_localize_cli/dart.yml?branch=main&style=flat-square" alt="build status"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License: MIT"/></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Platform-Flutter%20%7C%20Dart-02569B.svg?style=flat-square" alt="Platform"/></a>
</p>

---

## 🎯 Why auto_localize_cli? (The Core Problem & Solution)

### The Real Problem in Flutter Localization
Localizing a Flutter app has always been a painful, repetitive chore. The hardest part is **not translating words**—modern AI (ChatGPT, Claude, Gemini) or translation tools can translate text into 50+ languages in seconds. 

The real nightmare is the **manual codebase surgery**:
1. Scanning through 50+ screens and hundreds of widgets to hunt down every hardcoded string.
2. Manually inventing hundreds of unique `camelCase` keys and copy-pasting them into `.arb` files.
3. Breaking ancestor `const` trees across your entire UI and dealing with red compile errors.
4. Passing `BuildContext` deep into controllers, BLoCs, and repositories just to show an error message.

---

### Our Solution & The 2-Step Workflow
`auto_localize_cli` exists to eliminate this painful manual work permanently. 

It acts as an automated compiler bridge between your raw Flutter widgets and multilingual `.arb` catalogs:

1. **Step 1: Single-Command AST Extraction**
   Run `dart run auto_localize_cli:extract`. The CLI uses the Dart Analyzer AST to:
   - Extract all hardcoded strings into your base template (`lib/l10n/app_en.arb`) with smart `camelCase` keys.
   - Automatically clean ancestor `const` modifiers so your widgets compile with zero errors.
   - Rewrite your widgets to use a clean, context-less `l10n.<key>` getter anywhere in your app (UI, BLoCs, Repositories).

2. **Step 2: Instant Multilingual Expansion with AI**
   Now that all your app's strings are centralized into one clean `app_en.arb` file:
   - Copy `app_en.arb` and paste it into ChatGPT / Claude / Gemini with:  
     *"Translate this Flutter ARB into Spanish (`es`), preserving all keys and `{placeholder}` tokens."*
   - Save the result as `lib/l10n/app_es.arb` (or `app_bn.arb`, `app_ar.arb`, etc.).
   - Run `flutter gen-l10n`.

**Result:** Your app is now 100% multilingual across as many languages as you want—with zero manual widget editing, zero `BuildContext` boilerplate, and zero compile errors!

---

## ⚡ Quick Start: From Zero to Multilingual in 4 Steps

### Step 1: Install
Add `auto_localize_cli` to your Flutter project's `dev_dependencies`:
```bash
flutter pub add dev:auto_localize_cli
```

### Step 2: Initialize
Scaffold your localization architecture:
```bash
dart run auto_localize_cli:init
```
*(Or specify a custom base language: `-l es`, `-l ru`, `-l bn`)*

**Under the Hood (`init` Logic):**
- Automatically checks and configures `pubspec.yaml` with `flutter_localizations`, `intl`, and `generate: true`.
- Generates `l10n.yaml` with pre-wired paths.
- Creates `lib/l10n/app_en.arb` template.
- Scaffolds `lib/core/localization/localization_helper.dart` (providing `globalNavigatorKey`, context-less `l10n`, and reactive `changeAppLocale`). *Placed inside a dedicated `localization/` subfolder so it never conflicts with or pollutes existing Clean Architecture `lib/core/` directories!*
- Scaffolds `lib/core/localization/app_strings.dart` for centralized non-UI strings and error messages.

### Step 3: Connect `MaterialApp` (One-Time Setup)
In your `lib/main.dart`, pass `globalNavigatorKey`:
```dart
import 'package:your_app/core/localization/localization_helper.dart';

MaterialApp(
  navigatorKey: globalNavigatorKey, // <-- Enables context-less l10n everywhere!
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const HomeScreen(),
)
```

### Step 4: Extract All Hardcoded Strings
Whenever you write Flutter widgets with hardcoded text, run:
```bash
dart run auto_localize_cli:extract
```

**Under the Hood (`extract` Logic):**
- Traverses your Dart Abstract Syntax Tree (AST) to identify hardcoded UI strings (Text, Tooltips, Dialogs, Form Validators, etc.) using a Dual-Mode Whitelist.
- Generates clean, deduplicated `camelCase` keys and ICU parameterized placeholders.
- Non-destructively updates `lib/l10n/app_en.arb` (preserving all existing translations).
- Deletes enclosing `const` tokens up the widget tree so your app compiles instantly with zero errors.
- Automatically inserts the helper import and rewrites `Text('Welcome Back')` ➔ `Text(l10n.welcomeBack)`.
- Automatically compiles Dart localizations via `flutter gen-l10n`.

### Step 5: Add Other Languages in 2 Minutes (AI Workflow)
1. Copy `lib/l10n/app_en.arb` into ChatGPT / Claude:  
   *"Translate this Flutter ARB into Spanish (`es`), keeping keys untouched."*
2. Save as `lib/l10n/app_es.arb`.
3. Run `flutter gen-l10n`.
4. Switch languages live: `changeAppLocale(const Locale('es'))`.

---

## 📖 Table of Contents
1. [🎯 Why `auto_localize_cli`? (The Core Problem & Solution)](#-why-auto_localize_cli-the-core-problem--solution)
2. [⚡ Quick Start: From Zero to Multilingual in 4 Steps](#-quick-start-from-zero-to-multilingual-in-4-steps)
3. [Section 1: Overview & Architectural Comparison](#section-1-overview--why-auto_localize_cli-exists)
4. [Section 2: Deep Dive into the `lib/core/localization/` Architecture & Why It Must Be Maintained](#section-2-deep-dive-into-the-libcorelocalization-architecture--why-it-must-be-maintained)
   - [A. `lib/core/localization/localization_helper.dart` (The Context-Less Engine)](#a-libcorelocalizationlocalization_helperdart-the-context-less-engine)
   - [B. `lib/core/localization/app_strings.dart` (Centralized Non-UI & Business Logic Strings)](#b-libcorelocalizationapp_stringsdart-centralized-non-ui--business-logic-strings)
5. [Section 3: Using in Existing / Partially Localized Projects & Folder Structure Guide](#section-3-using-in-existing--partially-localized-projects--folder-structure-guide)
   - [A. Mandatory vs. Configurable Folder Structure](#a-mandatory-vs-configurable-folder-structure)
   - [B. 100% Non-Destructive Guarantee for Existing `.arb` Files](#b-100-non-destructive-guarantee-for-existing-arb-files)
   - [C. Step-by-Step Migration Playbook](#c-step-by-step-migration-playbook)
6. [Section 4: Where the CLI Extracts Strings From (Dual-Mode AST Whitelist)](#section-4-where-the-cli-extracts-strings-from-dual-mode-ast-whitelist)
7. [Section 5: The 7-Step Smart `camelCase` Key Generation Algorithm](#section-5-the-7-step-smart-camelcase-key-generation-algorithm)
8. [Section 6: Advanced String Interpolation & Parameterized `.arb` Generation](#section-6-advanced-string-interpolation--parameterized-arb-generation)
9. [Section 7: Compiler-Grade Edge Cases & Smart Ignore Rules](#section-7-compiler-grade-edge-cases--smart-ignore-rules)
10. [Section 8: Enterprise Monorepo Scalability (100K to 50M+ Files Architecture)](#section-8-enterprise-monorepo-scalability-100k-to-50m-files-architecture)
11. [Section 9: Detailed CLI Command Reference & Flags](#section-9-quick-start--cli-command-reference)

---

## Section 1: Overview & Why `auto_localize_cli` Exists

Localization is essential for building modern, international Flutter applications. However, both new (**greenfield**) and existing (**brownfield**) projects suffer from major developer experience roadblocks when attempting to internationalize.

Traditionally, developers must choose between two suboptimal paths:
1. **Manual `flutter gen-l10n`:** Clean and compile-safe, but demands painful clerical work—manually copy-pasting strings into `.arb` files, inventing keys, formatting ICU syntax, and passing `BuildContext` into every layer of the app.
2. **Runtime String Extensions (e.g. `"my_key".tr`):** Convenient in syntax, but introduces dangerous runtime bugs, offers zero compile-time safety, fails to autocomplete in IDEs, and frequently leads to missing keys appearing in production.

`auto_localize_cli` bridges this gap permanently. It operates directly on your Dart Abstract Syntax Tree (AST) using `package:analyzer`, giving you the ergonomics of a global accessor with the full compile-time safety and performance of Flutter's native localization system.

### Detailed Comparison Table

| Feature / Dimension | Manual `flutter gen-l10n` | String Extensions (`"key".tr`) | `auto_localize_cli` (`l10n.key`) |
|:---|:---:|:---:|:---:|
| **Manual `.arb` Copy-Pasting** | ❌ Required for every string | ❌ Required in JSON/Map | ✅ **100% Automated via AST CLI** |
| **IDE Autocomplete & IntelliSense** | ✅ Supported (`AppLocalizations`) | ❌ Broken (plain strings) | ✅ **100% Supported (`l10n.<key>`)** |
| **Compile-Time Type & Spelling Safety** | ✅ Yes | ❌ No (runtime failures/typos) | ✅ **100% Compile-Time Safe** |
| **`BuildContext` Requirement** | ❌ Mandatory (`.of(context)!`) | ✅ Optional | ✅ **Zero `context` needed anywhere** |
| **Works in BLoC, Cubit & Repositories** | ❌ Anti-pattern (passes context) | ⚠️ Runtime lookup | ✅ **Native architectural support** |
| **Ancestor `const` Cleanup** | ❌ Manual tree surgery | ❌ Manual tree surgery | ✅ **Automated AST parent traversal** |
| **String Interpolation (`$var`, `${expr}`)** | ❌ Manual ICU template setup | ⚠️ Runtime arg substitution | ✅ **Automated `@placeholders` generation** |
| **Safe Before `MaterialApp` Mounts** | ❌ Crashes with `StateError` | ⚠️ Inconsistent | ✅ **Safe `lookupAppLocalizations` fallback** |
| **Monorepo Scalability (100K–50M+ files)** | ❌ Manual bottlenecks | ❌ Large runtime JSON maps | ✅ **Streaming O(1) RAM + Incremental Sharded Cache** |

---

## Section 2: Deep Dive into the `lib/core/localization/` Architecture & Why It Must Be Maintained

When you run `dart run auto_localize_cli:init`, the CLI scaffolds two critical architectural files inside a dedicated subfolder: `lib/core/localization/`.

> [!NOTE]
> **Why inside a dedicated `localization/` subfolder?**  
> In modern Flutter production apps (especially those following Clean Architecture, Feature-First, BLoC, Cubit, or MVVM), developers frequently already maintain their own `lib/core/` directory containing modules such as `core/network/`, `core/theme/`, `core/constants/`, or `core/utils/`.  
> Placing our files in `lib/core/localization/` ensures `auto_localize_cli` **never litters, pollutes, or causes filename collisions** with your existing root `lib/core/` files.

### A. `lib/core/localization/localization_helper.dart` (The Context-Less Engine)

This file houses the global accessor and reactive state controller for your application's localizations:

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

GlobalKey<NavigatorState>? _customNavigatorKey;

/// If your project already has an existing rootNavigatorKey (e.g. from GoRouter or a custom router),
/// register it here so `l10n` accesses localization from your existing key seamlessly:
void setGlobalNavigatorKey(GlobalKey<NavigatorState> key) => _customNavigatorKey = key;

/// Live locale notifier for dynamic runtime locale switching without restart
final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);

/// Changes the active application locale at runtime and notifies listeners.
void changeAppLocale(Locale? locale) {
  localeNotifier.value = locale;
  _overrideLocale = locale;

  void markDirty(Element el) {
    el.markNeedsBuild();
    el.visitChildren(markDirty);
  }

  final ctx = (_customNavigatorKey?.currentContext ??
      globalNavigatorKey.currentContext) as Element?;
  if (ctx != null) {
    markDirty(ctx);
  }
}

Locale? _overrideLocale;
void setAutoLocalizeLocale(Locale? locale) => changeAppLocale(locale);

/// Context-less global getter for localized application strings.
AppLocalizations get l10n {
  final context = _customNavigatorKey?.currentContext ??
      globalNavigatorKey.currentContext;
  if (context != null) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      return localizations;
    }
  }

  // Pre-Mount Safe Fallback: invoked when l10n is called before MaterialApp mounts
  final targetLocale = _overrideLocale ?? localeNotifier.value ?? ui.PlatformDispatcher.instance.locale;
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == targetLocale.languageCode) {
      return lookupAppLocalizations(supported);
    }
  }
  return lookupAppLocalizations(AppLocalizations.supportedLocales.first);
}
```

#### Why Developers Must Maintain This File:
1. **The `globalNavigatorKey`:** Attaching `navigatorKey: globalNavigatorKey` to your root `MaterialApp` provides the active `BuildContext` to `l10n` from anywhere in your app without having to pass context through widget constructors or business logic layers.
2. **Existing `rootNavigatorKey` Support:** If your project already has an established `rootNavigatorKey`, simply call `setGlobalNavigatorKey(yourExistingKey)` in `main()`—no need to rewrite your navigation layer!
3. **Pre-Mount Safe Fallback (`lookupAppLocalizations`):** When constructing `MaterialApp(title: l10n.appTitle, ...)`, `title` is evaluated as an argument **before** the `NavigatorState` is mounted. Instead of throwing a `StateError: Localization accessed before NavigatorState context was initialized`, `l10n` safely falls back to `PlatformDispatcher.instance.locale` via `lookupAppLocalizations(locale)`.
4. **Reactive Runtime Language Switching:** Calling `changeAppLocale(const Locale('es'))` updates `localeNotifier`, rebuilds the widget tree, and marks the active element dirty, providing instant multilingual UI updates with zero application restart.

---

### B. `lib/core/localization/app_strings.dart` (Centralized Non-UI & Business Logic Strings)

#### Why the AST Engine Does Not Blindly Extract Strings from Logic Files:
In data layers, repositories, BLoCs, Cubits, and network interceptors, string literals are almost always technical:
- JSON deserialization keys (`json['user_id']`)
- HTTP endpoints (`/api/v1/auth/login`)
- SQL queries and query parameters (`WHERE status = 'ACTIVE'`)
- Analytical telemetry tags and event names

Blindly replacing these with localization getters would instantly break business logic and corrupt network payloads.

#### When Developers Must Use `AppStrings`:
All non-UI, user-facing error messages and business messages belong in `lib/core/localization/app_strings.dart`:
- Dio/HTTP error interceptors (`AppStrings.networkError`)
- BLoC/Cubit failure states (`emit(OrderError(AppStrings.timeoutError))`)
- Form validation error messages (`AppStrings.invalidEmail`)
- System and push notification bodies

#### Before & After Transformations in `AppStrings`:

```dart
// ==================== BEFORE (Hardcoded) ====================
class AppStrings {
  AppStrings._();
- Form validation error messages (`AppStrings.invalidEmail`)
- System and push notification bodies

#### Before & After Transformations in `AppStrings`:

```dart
// ==================== BEFORE (Hardcoded) ====================
class AppStrings {
  AppStrings._();

  // 1. Standard static getter
  static String get networkError => "Please check your internet connection";

  // 2. static const String field
  static const String serverError = "Internal database connection timeout";

  // 3. Parameterized method with interpolation
  static String welcomeUser(String name, int count) =>
      "Welcome back $name, you have $count pending notifications";
}

// ==================== AFTER (auto_localize_cli:extract) ====================
import 'localization_helper.dart';

class AppStrings {
  AppStrings._();

  // 1. Standard static getter -> Dynamic l10n lookup
  static String get networkError => l10n.pleaseCheckYourConnection;

  // 2. static const String -> Automatically converted to dynamic getter!
  static String get serverError => l10n.internalDatabaseConnectionTimeout;

  // 3. Parameterized method -> Parameterized l10n method call!
  static String welcomeUser(String name, int count) =>
      l10n.welcomeBackNameNotifications(name, count);
}
```

> [!IMPORTANT]
> **Automatic `static const` Conversion:** `auto_localize_cli` automatically detects `static const String` fields in `lib/core/localization/app_strings.dart` and rewrites them into dynamic getters (`static String get ... => l10n...`). If left as `const`, the value would freeze into memory at app boot, completely preventing live runtime language switching!

---

## Section 3: Using in Existing / Partially Localized Projects & Folder Structure Guide

`auto_localize_cli` is engineered specifically for **brownfield integration**. You can introduce it into an existing, production Flutter application with 100% confidence.

### A. Mandatory vs. Configurable Folder Structure

```
my_flutter_app/
├── pubspec.yaml                  # [Standard] CLI ensures dependencies & generate: true
├── l10n.yaml                     # [Configurable] Custom arb-dir and template paths supported!
├── lib/
│   ├── core/                     # [Your existing Clean Architecture or Core modules]
│   │   ├── network/              # [Untouched]
│   │   ├── theme/                # [Untouched]
│   │   └── localization/         # [DEDICATED SUBFOLDER - Auto-created by `init`]
│   │       ├── localization_helper.dart
│   │       └── app_strings.dart
│   ├── l10n/                     # [Configurable via l10n.yaml: arb-dir]
│   │   ├── app_en.arb
│   │   └── app_es.arb
│   └── features/                 # [Your Existing Feature Code]
│       ├── auth/
│       └── home/
```

| Path | Status | Description |
|:---|:---:|:---|
| `lib/core/localization/localization_helper.dart` | **Mandatory** | Contains `globalNavigatorKey`, `l10n`, and `changeAppLocale`. Auto-created by `init` in dedicated subfolder. |
| `lib/core/localization/app_strings.dart` | **Mandatory** | Central repository for non-UI user-facing strings. Auto-created by `init` in dedicated subfolder. |
| `l10n.yaml` | **Configurable** | If your project already has `l10n.yaml` pointing to a custom directory (e.g. `arb-dir: lib/src/localization`), `extract` reads your `l10n.yaml` and respects your custom paths. |
| `.arb` Directory & Files | **Configurable** | Honors existing template names (`app_en.arb`, `intl_en.arb`, etc.). |

---

### B. 100% Non-Destructive Guarantee for Existing `.arb` Files

When `auto_localize_cli:extract` runs on an existing project with established `.arb` files:
1. **Reverse-Lookup Key Deduplication:** The CLI builds an in-memory reverse lookup map (`Exact Text -> Existing Key`) of all existing translations. If your `.arb` already has `"Cancel": "btnCancel"`, the CLI reuses `l10n.btnCancel` in your widgets rather than inventing a duplicate key!
2. **Never Deletes or Overwrites Translations:** New keys are appended cleanly to your primary template ARB file. Existing keys, comments, and metadata are 100% preserved.
3. **Side-by-Side Coexistence:** Existing code using `AppLocalizations.of(context)!.myOldKey` continues to compile and function without modification alongside new `l10n.newKey` calls.

---

### C. Step-by-Step Migration Playbook

#### Scenario A: Brand New Flutter App
```bash
# 1. Initialize scaffolding (creates l10n.yaml, lib/l10n/app_en.arb, lib/core/localization/)
dart run auto_localize_cli:init

# 2. Build your Flutter widgets with plain, hardcoded strings...
# Text("Welcome Home"), InputDecoration(hintText: "Enter email")...

# 3. Run extract to convert all hardcoded strings into ARB keys and context-less l10n getters:
dart run auto_localize_cli:extract
```

#### Scenario B: Existing App with Standard `MaterialApp`
In your existing `main.dart`, attach `globalNavigatorKey` from `localization_helper.dart`:

```dart
import 'package:flutter/material.dart';

// 1. Import localization_helper.dart (generated by `init`):
import 'package:your_app_name/core/localization/localization_helper.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier, // Live dynamic language switching without restart!
      builder: (context, currentLocale, _) {
        return MaterialApp(
          navigatorKey: globalNavigatorKey, // <-- Wire key from localization_helper.dart
          locale: currentLocale,
          title: l10n.appTitle, // <-- Safe pre-mount fallback!
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        );
      },
    );
  }
}
```

#### Scenario C: App Using `GoRouter` (Declarative Routing)
If you use declarative routing like `GoRouter`, pass `globalNavigatorKey` directly into your `GoRouter` instance:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 1. Import localization_helper.dart:
import 'package:your_app_name/core/localization/localization_helper.dart';

final goRouter = GoRouter(
  navigatorKey: globalNavigatorKey, // <-- Pass globalNavigatorKey directly to GoRouter!
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
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, currentLocale, _) {
        return MaterialApp.router(
          routerConfig: goRouter,
          locale: currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}
```

#### Scenario D: Projects with an Existing `rootNavigatorKey`
If your existing project already defines its own navigation key (for example, `final rootNavigatorKey = GlobalKey<NavigatorState>();` inside `lib/routes/app_router.dart` or `lib/core/router.dart`), you have **three zero-friction options**:

##### Option 1: One-Line Registration via `setGlobalNavigatorKey` (Recommended)
In your `main()` function, simply pass your existing `rootNavigatorKey` to `setGlobalNavigatorKey`:
```dart
import 'package:flutter/material.dart';

// 1. Import localization_helper.dart:
import 'package:your_app_name/core/localization/localization_helper.dart';
// 2. Import your existing router file:
import 'package:your_app_name/routes/app_router.dart'; // Where rootNavigatorKey is defined

void main() {
  // Wire your existing key into auto_localize:
  setGlobalNavigatorKey(rootNavigatorKey);
  runApp(const MyApp());
}
```
Now `l10n` automatically reads the active `BuildContext` from your existing `rootNavigatorKey` with zero other changes required!

##### Option 2: 1-Line Alias in `lib/core/localization/localization_helper.dart`
Open the generated `lib/core/localization/localization_helper.dart` and point `globalNavigatorKey` directly to your existing key:
```dart
import 'package:your_app_name/routes/app_router.dart';

// Alias your existing key:
final GlobalKey<NavigatorState> globalNavigatorKey = rootNavigatorKey;
```

##### Option 3: Wire `globalNavigatorKey` into your existing router
In your existing router file, assign `rootNavigatorKey` to `globalNavigatorKey`:
```dart
import 'package:your_app_name/core/localization/localization_helper.dart';

final rootNavigatorKey = globalNavigatorKey;
```

#### Scenario E: Migrating an Old `AppConstants` String Class
If your project currently stores strings in `lib/constants/app_strings.dart`:
1. Move those string getters/fields into `lib/core/localization/app_strings.dart`.
2. Run `dart run auto_localize_cli:extract`.
3. The CLI automatically localizes all entries, converts `static const` to getters, and wires them to `l10n`.

---

## Section 4: Where the CLI Extracts Strings From (Dual-Mode AST Whitelist)

`auto_localize_cli` employs a **Dual-Mode AST Whitelist** to achieve 100% extraction precision without touching technical strings:

### Mode 1: Positional First Argument of Whitelisted Widgets
The CLI extracts the literal string passed as the first positional argument to:
- `Text("Hello World")`
- `SelectableText("Selectable text here")`
- `Tooltip(message: "Tooltip text", child: ...)`

### Mode 2: Whitelisted Named UI Parameters
The CLI extracts string literals assigned to any of the following 17 standard Flutter UI parameters:
- `title:` (e.g., `AppBar(title: const Text("Home"))` or `ListTile(title: Text("Title"))`)
- `subtitle:`
- `label:`
- `hintText:` (e.g., `InputDecoration(hintText: "Enter email")`)
- `labelText:`
- `helperText:`
- `errorText:`
- `counterText:`
- `prefixText:`
- `suffixText:`
- `semanticLabel:` / `semanticsLabel:`
- `tooltip:`
- `message:`
- `text:`
- `confirmText:`
- `cancelText:`
- `header:` / `content:`

### Mode 3: All Fields, Getters & Methods in `lib/core/localization/app_strings.dart`
All string literals defined within `lib/core/localization/app_strings.dart` are extracted automatically.

---

## Section 5: The 7-Step Smart `camelCase` Key Generation Algorithm

The CLI generates clean, idiomatic, collision-free `camelCase` keys:

```
[Raw Hardcoded String]
         │
         ▼
[Step 1: Sanitization & Filtering] ──────> Skip if URL, Email, Pure Number
         │
         ▼
[Step 2: Tokenization & Contractions] ───> "It's" -> "Its"
         │
         ▼
[Step 3: Leading Number Repositioning] ──> "404 Page Not Found" -> "page404NotFound"
         │
         ▼
[Step 4: Stopword Pruning] ──────────────> Filter noise words
         │
         ▼
[Step 5: Head + Tail Key Synthesis] ─────> First 3 words + Meaningful Tail word
         │
         ▼
[Step 6: Reserved Keyword Protection] ───> "Continue" -> "continueText"
         │
         ▼
[Step 7: Multi-Stage Collision Fallback] ─> 1st-last -> 2nd-last -> 3rd-last -> Suffix
```

### Examples of Key Generation

| Raw String | Generated Key | Rule Applied |
|:---|:---|:---|
| `"404 Page Not Found"` | `page404NotFound` | Leading number swapped after first semantic word |
| `"24 7 Customer Support Available"` | `customer247Available` | Multiple leading numbers repositioned |
| `"Continue"` | `continueText` | Dart reserved keyword disambiguation |
| `"Return"` | `returnText` | Dart reserved keyword disambiguation |
| `"User account status has been temporarily suspended"` | `userAccountStatusSuspended` | 4-word rule with meaningful tail word |
| `"User account status has been permanently banned"` | `userAccountStatusBanned` | Collision fallback selecting distinct tail word |
| `"It's Alice's dashboard"` | `itsAlicesDashboard` | Contraction & possessive sanitization |
| `"Служба 24 7 поддержки доступна"` | `sluzhba247Dostupna` | Cyrillic & multilingual transliteration |

---

## Section 6: Advanced String Interpolation & Parameterized `.arb` Generation

`auto_localize_cli` parses `StringInterpolation` nodes into native ICU message formats:

### Before & After Transformation

```dart
// ==================== BEFORE (Source Code) ====================
Text("Welcome back $userName, you have ${order.itemCount + 1} items waiting in cart")

// ==================== AFTER (Source Code) ====================
Text(l10n.welcomeBackUserNameItemsWaiting(userName, order.itemCount + 1))
```

### Generated `.arb` Entry with Placeholders Metadata
```json
{
  "welcomeBackUserNameItemsWaiting": "Welcome back {userName}, you have {orderItemCount1} items waiting in cart",
  "@welcomeBackUserNameItemsWaiting": {
    "placeholders": {
      "userName": {},
      "orderItemCount1": {}
    }
  }
}
```

### Advanced Interpolation Features:
1. **Deduplication:** Repeated variables in the same string (`"Price: $rate, discounted: $rate"`) generate a single `{rate}` placeholder in ARB and pass `rate` only once in code (`l10n.priceRateDiscounted(rate)`).
2. **Collision Disambiguation:** Disambiguates identical property names from different objects (`${sender.name}` and `${recipient.name}` become `{senderName}` and `{recipientName}`).
3. **Escaped Characters in ICU:** Automatically escapes single quotes (`'`) required by ICU formatting standards.

---

## Section 7: Compiler-Grade Edge Cases & Smart Ignore Rules

The CLI features 8 compiler protections ensuring 100% zero-defect source code generation:

1. **Automated Ancestor `const` Removal:** Walks up the AST tree and deletes `const` tokens from parent widgets, constructor calls, and literal arrays/maps, preventing compilation errors.
2. **Bottom-to-Top Source Rewriting:** Edits are sorted in descending offset order so character replacements never invalidate subsequent offsets.
3. **`AdjacentStrings` Merging:** Multi-line concatenated string literals (`"Hello " "World"`) are merged into a single string before key generation.
4. **`part` / `part of` Directive Safety:** Part files in Dart cannot contain `import` statements. The CLI automatically locates the parent library file and injects the helper import there.
5. **Default Parameter Protection:** Ignores default values in constructors (`{this.title = "Default"}`) since default values must remain compile-time constants.
6. **Assert & Super-Initializer Protection:** Ignores strings inside `assert(...)` statements and `super(...)` initializers.
7. **Pure Numbers & Symbols Ignored:** Strings like `"2026"`, `"100%"`, `"+91-9876543210"`, and `"₹500"` are ignored by default.
8. **Technical Strings Ignored:** Asset paths (`assets/logo.png`), URLs, emails, route names, and method channels are strictly preserved.

---

## Section 8: Enterprise Monorepo Scalability (100K to 50M+ Files Architecture)

To operate seamlessly in large enterprise monorepos, `auto_localize_cli` incorporates an industrial hyper-scale compiler architecture:

```
[Repository Files (10M+)]
          │
          ▼
[1. Zero-List Streaming Directory Traversal] ──> Skips .git, build, platform folders (O(1) RAM)
          │
          ▼
[2. Sharded Incremental File-Stat Cache] ──────> 256 JSON shards (.dart_tool/auto_localize_cli/cache/)
          │ (Cache Miss)
          ▼
[3. Pre-AST Lexical Fast-Reject Filter] ───────> Rejects 90%+ non-UI files in <0.01ms
          │ (Pass)
          ▼
[4. Multi-Core Isolate Worker Pool] ───────────> Parallel AST parsing across available CPU cores
          │
          ▼
[5. Deterministic Main-Thread ARB Resolution] ──> Sequential key assignment & bottom-to-top rewriting
```

### 1. Zero-List Streaming Directory Traversal ($O(1)$ RAM Footprint)
Never calls `.listSync(recursive: true).toList()`. Lazily streams `.dart` files with directory-level early pruning of hidden directories (`.git`, `.dart_tool`) and platform builds (`build`, `android`, `ios`, `web`, `windows`, `macos`, `linux`). Bounded backpressure chunking (max 64 open files per batch) prevents OS file descriptor limits (`EMFILE`).

### 2. Sharded Incremental File-Stat Cache
Stores file modification timestamps and byte sizes across 256 lightweight JSON shards in `.dart_tool/auto_localize_cli/cache/`. Second runs on 1,000 files complete in $<150\text{ms}$ with 0 files parsed!

### 3. Pre-AST Lexical Fast-Reject Filter
Before calling `package:analyzer`'s `parseString()`, an ultra-fast lexical check verifies whether the file contains string quotes and at least one whitelisted UI token. Non-UI models, services, DTOs, and repositories bypass AST parsing in $<0.01\text{ms}$!

### 4. $O(k)$ Sub-Second Git-Diff Mode (`--git-diff` / `-g`)
In multi-million-file repositories, developers only modify a handful of files per commit. `--git-diff` inspects `git status` and `git diff` to extract only from modified files in sub-second time.

### Benchmark Results (1,000 Files: 900 Non-UI Models, 100 UI Widgets)

| Run Type | Files Scanned | Fast-Rejected | Files Parsed | Cache Hits | Execution Time |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Run 1 (Initial Extraction)** | 1,000 | 900 | 100 | 0 | **2.3s** |
| **Run 2 (Incremental Cache Hit)** | 1,000 | 0 | 0 | 1,000 | **143ms** ⚡ |
| **Run 3 (Git-Diff Mode on 2 files)** | 2 | 0 | 2 | 0 | **65ms** ⚡ |

---

## Section 9: Quick Start & CLI Command Reference

### 1. Installation & Why Dev Dependencies

Add `auto_localize_cli` to your Flutter project's `dev_dependencies`:

```bash
# Using Flutter CLI (Recommended)
flutter pub add dev:auto_localize_cli

# Or using Dart CLI
dart pub add dev:auto_localize_cli
```

Or manually add it to your `pubspec.yaml`:

```yaml
dev_dependencies:
  auto_localize_cli: ^1.0.6
```

> [!TIP]
> **Zero Runtime Overhead (0 KB Bundle Impact):**  
> `auto_localize_cli` is strictly a development and build-time compiler tool. It operates directly on your source code AST during development. It adds **0 KB** to your final release APK, AAB, or IPA bundle size!

---

### 2. Under the Hood: The `init` & `extract` Engine Logic

#### 🛠️ What `dart run auto_localize_cli:init` Does (The Initialization Logic):
When you run `init`, the CLI executes a non-destructive 5-step scaffolding sequence:
1. **Dependency Analysis & Update:** Checks `pubspec.yaml` and non-destructively injects `flutter_localizations` (from Flutter SDK) and `intl: any`, while setting `flutter: generate: true`.
2. **Configuration Scaffolding:** Generates `l10n.yaml` with standard Flutter internationalization directives (or preserves your existing custom configuration if already present).
3. **Template ARB Creation:** Creates `lib/l10n/app_<locale>.arb` initialized with the base locale metadata.
4. **Dedicated Subfolder Isolation (`lib/core/localization/`):**
   - **Why a dedicated subfolder?** In production Flutter applications (especially Clean Architecture or Feature-First monorepos), developers often already have a `lib/core/` folder with `network/`, `theme/`, `constants/`, and `utils/`.
   - By creating `lib/core/localization/`, `auto_localize_cli` completely isolates its localization architecture, ensuring **zero file pollution, zero root directory clutter, and zero namespace clashes**.
5. **Context-Less Helper & Strings Scaffolding:**
   - Creates `lib/core/localization/localization_helper.dart` providing `globalNavigatorKey`, the pre-mount safe context-less getter `l10n`, and reactive locale switcher `changeAppLocale(...)`.
   - Creates `lib/core/localization/app_strings.dart` for centralized error and non-UI messages.

---

#### ⚡ What `dart run auto_localize_cli:extract` Does (The Extraction Logic):
When you run `extract`, the CLI executes an automated 7-stage AST compiler pipeline:
1. **Pre-Filtering & Sharded Caching:** Filters out generated files (`.g.dart`, `.freezed.dart`, `.mocks.dart`) and checks the 256-shard cache for unmodified files.
2. **Dual-Mode AST Parsing:** Uses Dart's official `analyzer` AST parser to detect user-facing strings (Text widgets, Tooltips, Dialogs, Form Validators, etc.) while strictly ignoring technical strings (JSON keys, URLs, routing paths, DB queries).
3. **Smart `camelCase` Key Generation:** Automatically converts phrases like `"404 Page Not Found"` into semantic, idiomatic keys (`page404NotFound`).
4. **Parameterized ICU Interpolation:** Automatically converts string interpolations (`"Welcome back $name, you have $count items"`) into parameterized ARB placeholders and generated Dart functions (`welcomeBackNameItems(name, count)`).
5. **Non-Destructive ARB Merging:** Appends newly extracted keys to `lib/l10n/app_en.arb` while strictly preserving all existing translations, comments, and metadata.
6. **AST Ancestor `const` Keyword Removal:** Walks up the AST parent tree and deletes enclosing `const` tokens from parent Column, Row, Padding, or widget trees, guaranteeing your code compiles instantly with zero errors.
7. **Import Injection & Code Rewriting:** Injects `import 'package:your_app/core/localization/localization_helper.dart';` and rewrites widgets from `Text('Hello')` to `Text(l10n.hello)`, followed by an automatic `flutter gen-l10n` build.

---

### 3. Step-by-Step Quick Start Workflow

#### Step 1: Initialize Localization
Run the initialization wizard in your Flutter project root:
```bash
dart run auto_localize_cli:init
```
*(Or specify your base language with `--locale ru`, `--locale es`, `--locale bn`)*

#### Step 2: Configure Your `MaterialApp`
In your `main.dart`, import `localization_helper.dart` and pass `globalNavigatorKey`:

```dart
import 'package:flutter/material.dart';

// 1. Import localization_helper.dart (generated automatically by `init`):
import 'package:your_app_name/core/localization/localization_helper.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier, // Live dynamic language switching without restart!
      builder: (context, currentLocale, _) {
        return MaterialApp(
          navigatorKey: globalNavigatorKey, // <-- Wire key from localization_helper.dart
          locale: currentLocale,
          title: l10n.appTitle, // <-- Safe pre-mount fallback!
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        );
      },
    );
  }
}
```

> [!TIP]
> **Existing `rootNavigatorKey`?** If your project already defines its own navigation key, simply call `setGlobalNavigatorKey(rootNavigatorKey);` in `main()` before `runApp()`.

#### Step 3: Extract Strings Automatically
Whenever you add or modify hardcoded UI strings, run:
```bash
dart run auto_localize_cli:extract
```

For fast CI/CD and large monorepos, extract only from uncommitted Git files:
```bash
dart run auto_localize_cli:extract --git-diff
```

> [!NOTE]
> **Automatic vs. Manual `flutter gen-l10n`:**
> `auto_localize_cli:extract` automatically attempts to run `flutter gen-l10n` at the end of extraction to immediately compile your ARB strings into `AppLocalizations`.
> 
> However, you can also run `flutter gen-l10n` manually at any time:
> ```bash
> flutter gen-l10n
> ```

#### Step 4: Adding More Languages (The 2-Minute AI Translation Workflow)

Once `auto_localize_cli:extract` finishes, all your hardcoded strings are neatly organized into your primary base template (`lib/l10n/app_en.arb`) with clean camelCase keys and ICU placeholders.

To support any other language (e.g. Spanish, French, Bengali, Arabic, German, Hindi):

1. **Copy your base ARB:** Open `lib/l10n/app_en.arb` and copy its contents.
2. **Translate with AI:** Paste the content into ChatGPT, Claude, Gemini, or your translation management tool with a prompt like:
   > *"Translate this Flutter .arb file into Spanish (`es`). Maintain all keys and `{placeholder}` tokens exactly as they are."*
3. **Save the translated file:** Create a new ARB file matching the locale code in `lib/l10n/`:
   - `lib/l10n/app_es.arb` (Spanish)
   - `lib/l10n/app_bn.arb` (Bengali)
   - `lib/l10n/app_ar.arb` (Arabic)
   - `lib/l10n/app_de.arb` (German)
4. **Recompile localization classes:** In your terminal, run:
   ```bash
   flutter gen-l10n
   ```
5. **Switch language live at runtime:** In your Flutter code, switch languages anytime with zero app restart:
   ```dart
   changeAppLocale(const Locale('es'));
   ```

That's it! Your entire application is now multilingual across any number of languages without ever manually touching widget code or passing `BuildContext` again.

### 4. Comprehensive CLI Command Reference

Below is the complete reference guide for every command, option, and flag available in `auto_localize_cli`.

---

#### 📦 Command 1: `dart run auto_localize_cli:init`

Scaffolds the complete localization architecture in your Flutter project from scratch. It is 100% non-destructive and will never overwrite existing `.arb` files or custom `l10n.yaml` configurations.

##### What It Does Under the Hood:
1. **Configures `pubspec.yaml`:** Adds `flutter_localizations` (from SDK) and `intl: any` under `dependencies`, and enables `flutter: generate: true`.
2. **Creates `l10n.yaml`:** Generates standard Flutter localization settings configured for `lib/l10n/` (respects existing `l10n.yaml` if already present).
3. **Scaffolds Template ARB:** Creates `lib/l10n/app_<locale>.arb` with `@@locale` initialized.
4. **Scaffolds `lib/core/localization/localization_helper.dart`:** Creates the context-less `l10n` global getter, `globalNavigatorKey`, `setGlobalNavigatorKey` (for existing `rootNavigatorKey`s), and reactive runtime locale switcher `changeAppLocale(...)`.
5. **Scaffolds `lib/core/localization/app_strings.dart`:** Creates the central catalog for user-facing non-UI error messages and business strings.

##### Options & Flags:

| Flag / Option | Shorthand | Type | Default | Description |
|:---|:---:|:---:|:---:|:---|
| `--locale` | `-l` | `String` | `'en'` | Specifies the primary base language for the template ARB file and `l10n.yaml`. |
| `--help` | `-h` | `bool` | `false` | Displays usage instructions and available options. |

##### Real-World Usage Examples:

```bash
# 1. Default setup: scaffolds English base template (lib/l10n/app_en.arb)
dart run auto_localize_cli:init

# 2. Russian base setup: scaffolds Russian base template (lib/l10n/app_ru.arb)
dart run auto_localize_cli:init --locale ru
dart run auto_localize_cli:init -l ru

# 3. Spanish base setup: scaffolds Spanish base template (lib/l10n/app_es.arb)
dart run auto_localize_cli:init -l es

# 4. Bengali base setup: scaffolds Bengali base template (lib/l10n/app_bn.arb)
dart run auto_localize_cli:init -l bn
```

---

#### ⚡ Command 2: `dart run auto_localize_cli:extract`

The core AST-powered localization engine. Scans your Dart source files, extracts hardcoded strings and interpolations into your template `.arb` file, removes ancestor `const` modifiers, and rewrites source files to use compile-safe `l10n.<key>` getters.

##### What It Does Under the Hood:
1. **$O(1)$ RAM Streaming Directory Traversal:** Lazily traverses `lib/` while early-pruning hidden folders (`.git`, `.dart_tool`) and build artifacts (`build`, `android`, `ios`, `web`, `windows`, `macos`, `linux`).
2. **Pre-AST Lexical Fast-Reject Filter:** Inspects file content in $<0.01\text{ms}$; bypasses 90%+ of non-UI files (models, DTOs, services, repositories) before AST parsing.
3. **Sharded Incremental File-Stat Cache:** Checks 256 JSON shards inside `.dart_tool/auto_localize_cli/cache/`. Skips unchanged files in sub-millisecond time.
4. **Multi-Core Isolate Worker Pool:** Distributes AST parsing across background isolates (`--workers`).
5. **Deterministic Sequential Key Generation:** Resolves smart `camelCase` keys and deduplicates entries on the main isolate in sorted file-path order.
6. **Bottom-to-Top Source Rewriting:** Applies string replacements, deletes ancestor `const` keywords, merges `AdjacentStrings`, and safely injects helper imports (including into parent libraries for `part of` files).
7. **Automated Recompilation:** Triggers `flutter gen-l10n` to regenerate `AppLocalizations` classes immediately.

##### Options & Flags:

| Flag / Option | Shorthand | Type | Default | Description |
|:---|:---:|:---:|:---:|:---|
| `--git-diff` | `-g` | `bool` | `false` | **Sub-second $O(k)$ extraction.** Uses Git to scan ONLY modified and untracked `.dart` files under `lib/`. Perfect for active development, pre-commit hooks, and massive monorepos. |
| `--no-cache` | | `bool` | `false` | Forces a complete re-scan and full AST parsing of every file in the project, ignoring the incremental file-stat cache. |
| `--workers` | `-w` | `int` | CPU Cores (max 8) | Number of parallel Isolate workers allocated for concurrent AST parsing. Defaults to `Platform.numberOfProcessors.clamp(1, 8)`. |
| `--locale` | `-l` | `String` | Auto-detected | Explicitly targets a specific ARB template file (e.g. `app_es.arb` or `app_ru.arb`). If omitted, auto-detected from `l10n.yaml`. |
| `--help` | `-h` | `bool` | `false` | Displays usage instructions and available options. |

##### Real-World Usage Examples:

```bash
# 1. Standard Extraction:
# Incremental extraction across all project files using automatic CPU workers & cache
dart run auto_localize_cli:extract

# 2. Sub-Second Git-Diff Extraction (Recommended for everyday coding & Git hooks):
# Only parses files you modified or created since last commit (<100ms execution)
dart run auto_localize_cli:extract --git-diff
dart run auto_localize_cli:extract -g

# 3. Force Full Re-Scan (Bypassing Cache):
# Forces a fresh full-repo re-scan and verifies AST idempotency
dart run auto_localize_cli:extract --no-cache

# 4. Custom Parallel Worker Count:
# Allocate specific worker isolates (e.g. 8 workers on a high-core CI build agent)
dart run auto_localize_cli:extract --workers 8
dart run auto_localize_cli:extract -w 4

# Run single-threaded for deterministic debugging:
dart run auto_localize_cli:extract -w 1

# 5. Extract into a Specific Base Language ARB:
dart run auto_localize_cli:extract --locale es
dart run auto_localize_cli:extract -l ru

# 6. Combined Power Flags for Enterprise Monorepos:
# Extract only Git-modified files with 4 parallel workers into Spanish template:
dart run auto_localize_cli:extract -g -w 4 -l es

# Full clean CI pipeline re-extraction:
dart run auto_localize_cli:extract --no-cache -w 8
```

---

## License

MIT License. Copyright (c) 2026 Dilip Sarkar.
