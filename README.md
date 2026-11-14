# auto_localize_cli

<p align="center">
  <img src="https://raw.githubusercontent.com/Dilip-2003/auto_localize_cli/main/assets/banner.png" alt="auto_localize_cli banner" width="600" onerror="this.style.display='none'"/>
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

## 🎯 The Problem vs. The Solution

### ❌ The Legacy Frustrations
1. **Manual `.arb` File Maintenance:** You spend hours copy-pasting strings into `app_en.arb`, manually inventing snake_case or camelCase keys, and formatting ICU placeholders by hand.
2. **Context Boilerplate Everywhere:** Flutter's default `AppLocalizations.of(context)!.myString` requires `BuildContext`. You can't cleanly access it inside Cubits, Blocs, Services, Models, or top-level getters.
3. **The Fragility of String Extensions (`"text".tr`):** Runtime key lookups (like Easy Localization or GetX) provide zero compile-time safety. A single typo in a key string passes compilation and silently breaks or shows raw keys in production.
4. **Const Keyword Compiler Hell:** In Flutter, whenever you replace `"Submit"` with localized text inside a `const Column(...)` or `const Text(...)`, the Dart compiler breaks with `Invalid constant value`. You have to manually locate and delete every ancestor `const` keyword up the entire widget tree.

### ✅ How `auto_localize_cli` Solves Everything
`auto_localize_cli` inspects your Dart Abstract Syntax Tree (AST) using the official Dart `analyzer` compiler package:
- 🚀 **1-Command Setup:** Scaffolds complete localization architecture, config files, and global accessors.
- 🔍 **AST-Powered Auto-Extraction:** Scans your UI widgets and core string classes for hardcoded strings.
- 🏷️ **Smart `camelCase` Keys:** Generates clean, human-readable keys using a deterministic 7-step NLP algorithm.
- 🪄 **Ancestor `const` Removal:** Walks up the AST hierarchy and cleanly removes invalidated ancestor `const` keywords from widgets and collections.
- 🔤 **String Interpolation & Placeholders:** Converts `"Order #$id has ${items.length + 1} items"` into parameterized ARB templates with typed `@placeholders` and deduplicated method calls.
- 🛡️ **Zero Runtime Errors:** Generates a compile-time safe, IDE-suggested, context-less `l10n.<key>` getter with safe pre-mount fallback.

---

## ✨ Key Features

- **⚡ Zero-Config Bottom-to-Top AST Rewriter:** Safely modifies Dart source files in place without altering your comments, indentation, or code style.
- **🌐 Context-Less `l10n` Getter:** Access your localized strings anywhere (`l10n.welcomeMessage`)—inside widgets, view models, repositories, and even before `MaterialApp` mounts.
- **🔄 Dynamic Runtime Locale Switching:** Switch languages live without restarting the app using `changeAppLocale(Locale('bn'))` and `localeNotifier`.
- **🧩 Parameterized String Interpolation:** Full support for `$variable`, `${user.name}`, math expressions, and deduplicated parameter calls.
- **🏛️ `part` / `part of` Architectural Support:** Automatically detects part files, updates them without illegal `import` statements, and safely injects dependencies into the parent library file.
- **📦 Core `AppStrings` Class Conversion:** Converts `static const String` error codes and message fields into dynamic `static String get` localization getters.
- **🔗 `AdjacentStrings` Merging:** Merges multi-line adjacent string literals (`"Hello " "World"`) into a single ARB entry.
- **🧠 Smart Ignore Engine:** Strictly skips non-localizable values: pure numbers (`"2026"`), symbols (`"100%"`, `"+91-9876543210"`, `"₹500"`), file paths, URLs, routes (`"/home"`), constructor default parameters (`this.title = "Default"`), constructor initializers, and `assert` statements.

---

## 🧠 7-Step Smart Key Generation Algorithm

`auto_localize_cli` applies a deterministic 7-step natural language algorithm to transform any sentence into clean, idiomatic `camelCase`:

| Raw String Literal | Generated Key | Applied Algorithmic Rules |
|:---|:---|:---|
| `"404 Page Not Found"` | `page404NotFound` | **Rule 3:** Repositions leading digits to first alphabetic word |
| `"24 7 Customer Support Available"` | `customer247Available` | **Rule 3:** Shifts first word to index 0 + **Rule 5:** First 3 words + tail |
| `"Continue"` | `continueText` | **Rule 6:** Appends `Text` suffix to protect Dart reserved keywords |
| `"Return"` | `returnText` | **Rule 6:** Protects Dart `return` keyword |
| `"Your account has been temporarily suspended"` | `yourAccountHasSuspended` | **Rule 4:** Prunes stopwords (`been`) and `-ly` adverbs (`temporarily`) |
| `"Your account has been permanently deleted"` | `yourAccountHasDeleted` | **Rule 4:** Prunes `-ly` adverbs (`permanently`) |
| `"Your account has been successfully verified"` | `yourAccountHasVerified` | **Rule 4:** Prunes stopwords and adverbs |
| `"Your account has been recently verified"` | `yourAccountHasVerified2` | **Rule 5 & 7:** Collision fallback on identical 3-word head & tail |
| `"Order #${order.id} has ${count} items"` | `orderOrderIdCount` | Parameterized template with `@placeholders: {orderId, count}` |
| `"It's $userName's dashboard"` | `itsUserNameDashboard` | Normalizes contractions and possessives (`It's` -> `Its`) |
| `"2026"`, `"100%"`, `"+91-9876543210"` | *(Ignored)* | **Rule 1:** Strings without alphabetic letters are strictly skipped |

---

## 🚀 Quick Start Guide

### Step 1: Add to `dev_dependencies`

In your Flutter project's `pubspec.yaml`:

```yaml
dev_dependencies:
  auto_localize_cli: ^1.0.0
```

Or run:

```bash
flutter pub add dev:auto_localize_cli
```

---

### Step 2: Initialize Localization (`init`)

Run the onboarding command from your Flutter project root:

```bash
dart run auto_localize_cli:init
```

This automated step:
1. Adds `flutter_localizations` & `intl` to `pubspec.yaml` with `generate: true`.
2. Creates `l10n.yaml`.
3. Creates template `lib/l10n/app_en.arb`.
4. Creates context-less global getter in `lib/core/localization_helper.dart`.
5. Creates centralized string catalog in `lib/core/app_strings.dart`.

#### Wire Up `main.dart`
Configure your `MaterialApp` with `globalNavigatorKey` and `localeNotifier`:

```dart
import 'package:flutter/material.dart';
import 'package:your_app_name/core/localization_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          navigatorKey: globalNavigatorKey,
          locale: currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          title: l10n.appTitle, // Safe pre-mount fallback!
          home: const HomeScreen(),
        );
      },
    );
  }
}
```

---

### Step 3: Write Normal Flutter Code

Develop your UI and business logic naturally with standard string literals:

```dart
// lib/core/app_strings.dart
import 'localization_helper.dart';

class AppStrings {
  AppStrings._();

  static String get networkError => "Please check your internet connection";
  static const String serverTimeout = "Server connection timed out";
}

// lib/screens/home_screen.dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = "Dilip";
    final count = 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Overview"),
      ),
      body: Column(
        children: [
          const Text("24 7 Customer Support Available"),
          Text("Welcome back $userName, you have $count new messages!"),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }
}
```

---

### Step 4: Run Extraction (`extract`)

Run the extraction command:

```bash
dart run auto_localize_cli:extract
```

#### ⚡ Before vs. After Code Diff

```diff
- import 'package:flutter/material.dart';
+ import 'package:flutter/material.dart';
+ import 'package:your_app_name/core/localization_helper.dart';

  class HomeScreen extends StatelessWidget {
    const HomeScreen({super.key});

    @override
    Widget build(BuildContext context) {
      final userName = "Dilip";
      final count = 5;

      return Scaffold(
        appBar: AppBar(
-         title: const Text("Dashboard Overview"),
+         title: Text(l10n.dashboardOverview),
        ),
-       body: const Column(
+       body: Column(
          children: [
-           const Text("24 7 Customer Support Available"),
+           Text(l10n.customer247Available),
-           Text("Welcome back $userName, you have $count new messages!"),
+           Text(l10n.welcomeBackUserNameMessages(userName, count)),
            ElevatedButton(
              onPressed: () {},
-             child: const Text("Continue"),
+             child: Text(l10n.continueText),
            ),
          ],
        ),
      );
    }
  }
```

Your `lib/l10n/app_en.arb` is automatically populated and compiled:

```json
{
  "@@locale": "en",
  "dashboardOverview": "Dashboard Overview",
  "customer247Available": "24 7 Customer Support Available",
  "welcomeBackUserNameMessages": "Welcome back {userName}, you have {count} new messages!",
  "@welcomeBackUserNameMessages": {
    "placeholders": {
      "userName": {},
      "count": {}
    }
  },
  "continueText": "Continue"
}
```

---

### Step 5: Add Additional Languages & Switch Locales Live

Create a new translation file, e.g. `lib/l10n/app_bn.arb`:

```json
{
  "@@locale": "bn",
  "dashboardOverview": "ড্যাশবোর্ড ওভারভিউ",
  "customer247Available": "২৪ ৭ কাস্টমার সাপোর্ট উপলব্ধ",
  "welcomeBackUserNameMessages": "স্বাগতম {userName}, আপনার {count} টি নতুন বার্তা আছে!",
  "continueText": "চালিয়ে যান"
}
```

Rebuild localizations:

```bash
flutter gen-l10n
```

Switch languages dynamically anywhere in your app:

```dart
// Switch to Bengali
changeAppLocale(const Locale('bn'));

// Switch back to English
changeAppLocale(const Locale('en'));
```

The entire UI updates immediately without restarting the application!

---

## 🛠️ CLI Command Reference

| Command | Description |
|:---|:---|
| `dart run auto_localize_cli:init` | Scaffolds configuration, ARB catalog, and `l10n` context-less helper. |
| `dart run auto_localize_cli:extract` | Parses AST, extracts UI strings into `.arb`, removes ancestor `const`s, and rewrites source code. |

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an issue on [GitHub](https://github.com/Dilip-2003/auto_localize_cli).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

<p align="center">
  Crafted with ❤️ for the Flutter Community
</p>
