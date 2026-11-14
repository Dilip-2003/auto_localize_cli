# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0

### Added
- **Phase 1 Scaffolding (`auto_localize_cli:init`)**:
  - Automatically configures `flutter_localizations` and `intl` in `pubspec.yaml` with `generate: true`.
  - Creates `l10n.yaml` with standard Flutter localization configuration.
  - Generates template ARB catalog (`lib/l10n/app_en.arb`).
  - Scaffolds context-less global getter `l10n` (`lib/core/localization_helper.dart`) with pre-mount safe fallback.
  - Provides reactive runtime language switching through `localeNotifier` and `changeAppLocale(...)`.
  - Creates core error and string catalog (`lib/core/app_strings.dart`).

- **Phase 2 Extraction (`auto_localize_cli:extract`)**:
  - Compiler-grade AST parsing using `package:analyzer`.
  - Automatically locates hardcoded UI strings in widgets (`Text`, `SelectableText`, `Tooltip`, `InputDecoration`, `Semantics`, etc.) and core string classes.
  - Automatically walks up the AST hierarchy to remove ancestor `const` keywords on widgets and literal lists/maps, preventing compile-time errors.
  - Bottom-to-top source code rewriting preserving exact source code formatting and indentation.
  - Idempotent extraction (running multiple times results in 0 modifications).
  - Automatically triggers `flutter gen-l10n` after extraction.

- **String Interpolation & Parameterization**:
  - Extracts interpolated strings (`"Hello $userName"`, `"Total: ₹${order.totalAmount}"`).
  - Generates parameterized ARB entries with `@key` and `{placeholder}` ICU metadata.
  - Replaces string interpolations with parameterized method calls (`l10n.helloUserName(userName)`).
  - Automatically deduplicates repeated expressions in the same string (`"Hi $name, welcome back $name!"` passes `name` only once).

- **7-Step Smart `camelCase` Key Generation Algorithm**:
  - Step 1: Validation and filtering (ignores paths, URLs, emails, dates, pure numbers).
  - Step 2: CamelCase splitting and tokenization with contraction normalization (`It's` -> `Its`).
  - Step 3: Leading numbers repositioning (`"24 7 Customer Support Available"` -> `customer247Available`).
  - Step 4: Stopword and noise word pruning.
  - Step 5: Candidate key building (first 3 words + meaningful tail word) with 2nd/3rd-last word fallback for collisions.
  - Step 6: Reserved Dart keyword disambiguation (`"Continue"` -> `continueText`, `"Return"` -> `returnText`).
  - Step 7: Deterministic collision fallback with numeric suffixes if required.

- **Compiler-Grade Architectural Safety**:
  - `part` / `part of` support: Never injects imports into `part of` files; safely resolves and injects imports into the parent library file.
  - `AdjacentStrings` merging: Automatically merges multi-line concatenated string literals into a single localization key.
  - `AppStrings` field conversion: Automatically converts `static const String` fields into `static String get` getters to allow dynamic localization lookup.
  - Smart Ignore: Preserves compile-time constants like numbers (`"2026"`), symbols (`"100%"`, `"+91-9876543210"`), default parameter values (`this.title = "Default"`), and `assert` statements.
