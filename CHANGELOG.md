# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.1

### DX Automation & AppStrings Documentation
- **Automated Initialization Workflow**:
  - `auto_localize_cli init` now automatically executes `flutter pub get` and `flutter gen-l10n` during onboarding, instantly generating `lib/l10n/app_localizations.dart` and eliminating initial `uri_does_not_exist` IDE errors.
  - Streamlined post-init terminal instructions so developers can proceed immediately to connecting `MaterialApp`.
- **Clean Flutter 3.27+ `l10n.yaml` Generation**:
  - Removed obsolete `synthetic-package` option from generated `l10n.yaml` files to avoid deprecation warnings on modern Flutter SDKs.
- **`AppStrings` Architecture Documentation & Scaffold**:
  - Scaffolds `lib/core/localization/app_strings.dart` with in-file architectural documentation and usage examples.
  - Added dedicated documentation in `README.md` explaining how `AppStrings` centralizes domain/repository failure messages without `BuildContext`, and clarifying that its usage is completely optional.

## 1.1.0

### Production Hardening & Compiler Precision
- **Flutter 3.27+ Compatibility & Deterministic Localization**:
  - Configures `intl: any` in `pubspec.yaml` to prevent version solving conflicts with `flutter_localizations` on modern Flutter SDKs.
  - Generates deterministic `output-dir: lib/l10n` and `synthetic-package: false` in `l10n.yaml`, ensuring seamless imports across all Flutter versions.
  - Removed deprecated `package:flutter_gen` from initialization instructions.
- **Idiomatic Reactive Runtime Locale Switching**:
  - Removed unsafe recursive `markDirty` element tree traversal from `localization_helper.dart`, relying cleanly on `ValueListenableBuilder<Locale?>` and `WidgetsBinding.addPostFrameCallback`.
- **PreAstFilter Token Synchronization**:
  - Added missing whitelist tokens (`buttonText:`, `action:`, `prompt:`, `showToast`, `showSnackBar`, `showDialog`, `showAlert`) to `PreAstFilter`, eliminating silent false-rejects of UI helper files.
- **Restricted Non-UI String Extraction**:
  - Restricted getter and method extraction strictly to classes ending with `Strings`, `Errors`, `Messages`, or `Constants` (e.g. `AppStrings`), protecting data models, repositories, and services from unintended string extraction.
  - Preserves inline comments (`/* comment */`) between `const` and widget constructors when stripping `const`.
  - Added raw string interpolation guard (`r'...'`) to prevent raw strings with `$` from being parsed as interpolations.
- **Safe Import Placement & ARB-Aware Incremental Cache**:
  - Tracks `firstDeclarationOffset` to place helper imports below leading file-level comments (`// ignore_for_file:` or license headers).
  - Enhanced `IncrementalCacheManager` with `arbSignature` to automatically re-scan Dart files if `app_en.arb` is externally modified or keys are deleted.
- **Deduplicated CLI Architecture & Rich Practical Docs**:
  - Refactored `bin/init.dart` and `bin/extract.dart` to forward directly to unified `bin/auto_localize_cli.dart`.
  - Overhauled `README.md` with rich practical use cases for all CLI shorthands (`-f`, `-d`, `-g`, `-l`, `-w`) and declarative `GoRouter` setup.

## 1.0.7

### Architecture & Compiler Resilience
- **Unified CLI Entry Point (`auto_localize_cli`)**:
  - Added `bin/auto_localize_cli.dart` supporting subcommands: `auto_localize_cli init`, `auto_localize_cli extract`, `--version`, and `--help`.
  - Added global binary mappings in `pubspec.yaml` executables for direct PATH execution.
- **Targeted Single-File Extraction (`--file` / `-f`)**:
  - Added `--file <path>` option to extract strings from an individual Dart file without running a full directory crawl.
- **Dry-Run Preview Mode (`--dry-run` / `-d`)**:
  - Added `--dry-run` flag to preview extracted strings and files to be rewritten without modifying files on disk or ARB catalogs.
- **Atomic Two-Phase Commit**:
  - Implemented in-memory file modification buffering (`_PendingFileWrite`). ARB catalogs are committed first; Dart source files are rewritten only after ARB persistence succeeds, preventing partial extraction desynchronization.
- **Resilient ARB Error Handling**:
  - `ArbManager.load()` now rethrows `FormatException` and logs detailed syntax errors on malformed/merge-conflicted ARB files rather than silently erasing existing translations.
- **Unparameterized ICU Brace Escaping**:
  - Automatically escapes literal `{` and `}` in plain text strings as `'{'` and `'}'` in ARB catalogs to prevent ICU parameter mismatch in `flutter gen-l10n`.
- **Deterministic 32-bit FNV-1a Hashing**:
  - Implemented cross-platform deterministic FNV-1a hash generator for non-Latin script fallback keys (Bengali, Hindi, Arabic, Chinese).
- **Reserved Keyword Collision Protection**:
  - Disambiguates Flutter `AppLocalizations` static members (`supportedLocales`, `localizationsDelegates`, `delegate`, `default`, `class`) with a `Text` suffix to prevent compiler conflicts.
- **Contrasting Adverbs Preservation**:
  - Retains distinguishing adverbs (`temporarily`, `permanently`, `currently`, `immediately`) in semantic key generation.
- **Top-Level and Static `const` Variable Conversion**:
  - AST visitor automatically detects top-level and static `const` variables containing extracted UI widgets and rewrites `const` to `final`.
- **Non-UI Class Filtering**:
  - Strict AST ignore filter for non-UI classes (`Exception`, `FormatException`, `StateError`, `ArgumentError`, `Color`, `Uri`, `DateTime`, `File`, `Directory`, `Platform`, `Process`, `HttpClient`, `Logger`, and `print`).
- **Reactive Build-Phase Protection**:
  - `changeAppLocale` now safely schedules UI rebuilds via `WidgetsBinding.addPostFrameCallback` when invoked during widget build phases.
- **Multi-Stage Script Subtag Fallback**:
  - Pre-mount `l10n` fallback now evaluates exact script codes and country codes (e.g. `zh_Hant` vs `zh_Hans`).
- **Test Isolation Helper**:
  - Scaffolds `@visibleForTesting void resetLocalizationHelperForTesting()` for clean test teardowns.

## 1.0.6

### Architecture & Scaffolding Isolation
- **Dedicated Subfolder Isolation (`lib/core/localization/`)**:
  - Scaffolds `localization_helper.dart` and `app_strings.dart` inside a dedicated subfolder: `lib/core/localization/` instead of directly at the root of `lib/core/`.
  - Ensures clean separation and zero directory pollution for enterprise apps with existing `lib/core/` architectures (e.g. `core/network/`, `core/constants/`, `core/theme/`).
  - Updated AST code rewriter, directory crawler, and test suites to automatically inject and respect `lib/core/localization/localization_helper.dart`.
- **Comprehensive `init` & `extract` Engine Logic Documentation**:
  - Added detailed under-the-hood engine breakdowns for both `dart run auto_localize_cli init` and `dart run auto_localize_cli extract` directly into the Quick Start and Installation guides in `README.md` and `lib/auto_localize_cli.dart`.
  - Documented AST parsing stages, dual-mode whitelisting, ancestor `const` stripping, and 0 KB release bundle footprint.
- **Example App Updates**:
  - Updated `example/` structure and imports to `lib/core/localization/`.

## 1.0.5

### Example & Documentation Overhaul
- **Production-Grade Flutter Example Application**:
  - Overhauled `example/` into a complete, standalone, runnable Flutter UI application.
  - Implemented real-world demonstrations of context-less `l10n.<key>`, dynamic runtime language switching (`changeAppLocale`), parameterized translations (`welcomeBackUser`), and non-UI usage in repositories (`AuthRepository`).
  - Added standalone `example/pubspec.yaml`, `example/l10n.yaml`, and generated localization delegates achieving **0 issues** on `flutter analyze`.
- **Top-of-README Quick Start Guide**:
  - Moved the streamlined **"⚡ Quick Start: From Zero to Multilingual in 4 Steps"** directly to the top of `README.md`, clarifying installation, one-time `MaterialApp` connection, AST extraction, and AI-assisted multilingual translation.
- **Version Updates**:
  - Bumped package dependency examples and documentation to `^1.0.5`.

## 1.0.4

### Documentation
- Added high-priority **"Why auto_localize_cli? (The Core Problem & Solution)"** architectural overview to the very top of `README.md`.
- Documented the complete 2-step AST extraction and AI-assisted multilingual translation workflow.
- Updated installation instructions across documentation to `^1.0.4`.

## 1.0.3

### Documentation & Polishing
- Updated installation instructions across `README.md` and `example/README.md` with modern CLI commands (`flutter pub add dev:auto_localize_cli`).
- Polished dependency constraints and release packaging.

## 1.0.2

### Fixed
- **Analyzer 14.x Compatibility for 160/160 pub points**:
  - Expanded `analyzer` dependency constraint to `'>=6.4.0 <15.0.0'`, supporting the newest stable `analyzer 14.x` releases while maintaining 100% backward compatibility down to `6.4.0`.
  - Adapted AST visitor for Dart 3.13 / `analyzer 14.x` AST changes:
    - Handled `NamedArgument` in addition to legacy `NamedExpression`.
    - Handled `BlockClassBody` hierarchy and `ClassNamePart` type name extraction.
    - Handled `NamedType.name` alongside `NamedType.name2`.
    - Handled `FormalParameter` and `FormalParameterDefaultClause` parameter validation.
    - Simplified `PartOfDirective.libraryName` resolution with `.toSource()`.

## 1.0.1

### Fixed
- Expanded `analyzer` dependency constraint to support both `6.x` and `7.x` (`>=6.4.0 <8.0.0`) for maximum `pub.dev` score.
- Escaped angle brackets in documentation comments to comply with `dartdoc` HTML lint rules.

## 1.0.0

### Added
- **Phase 1 Scaffolding (`auto_localize_cli init`)**:
  - Automatically configures `flutter_localizations` and `intl` in `pubspec.yaml` with `generate: true`.
  - Creates `l10n.yaml` with standard Flutter localization configuration.
  - Generates template ARB catalog (`lib/l10n/app_en.arb` or custom base locale via `--locale` / `-l`).
  - Scaffolds context-less global getter `l10n` (`lib/core/localization_helper.dart`) with pre-mount safe fallback (`lookupAppLocalizations`) and seamless existing `rootNavigatorKey` integration via `setGlobalNavigatorKey`.
  - Provides reactive runtime language switching through `localeNotifier` and `changeAppLocale(...)`.
  - Creates core error and string catalog (`lib/core/app_strings.dart`).

- **Hyper-Scale Architecture for Enterprise Monorepos (100K to 50M+ Files)**:
  - **Zero-List Streaming Directory Traversal ($O(1)$ RAM)**: Lazily streams Dart files with directory-level early pruning of hidden (`.git`, `.dart_tool`) and build/platform folders (`build`, `android`, `ios`, `web`, `macos`, `linux`, `windows`), preventing OutOfMemoryError.
  - **Bounded Backpressure Chunking**: Restricts concurrent open files to batches of 64, completely eliminating OS file descriptor limits (`EMFILE`).
  - **Pre-AST Lexical Fast-Reject Filter**: Fast $<0.01\text{ms}$ check bypasses 90%+ of non-UI files (models, DTOs, services, repositories) before invoking the Dart analyzer AST parser.
  - **Sharded Incremental File-Stat Cache**: Partitions file modification timestamps across 256 lightweight JSON shards in `.dart_tool/auto_localize_cli/cache/`. Second runs on 1,000 files complete in $<150\text{ms}$ with 0 files parsed.
  - **Multi-Core Isolate Worker Pool**: Parallelizes AST parsing across CPU cores (`--workers`) with deterministic sequential main-thread ARB key resolution.
  - **$O(k)$ Git-Diff Mode (`--git-diff` / `-g`)**: Extracts only from uncommitted and untracked Git files, achieving sub-second extraction in multi-million-file repositories.

- **Phase 2 Extraction (`auto_localize_cli extract`)**:
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
  - Multilingual & Cyrillic transliteration support (Russian, Ukrainian, Belarusian, Bulgarian $\rightarrow$ Latin `camelCase`).

- **Compiler-Grade Architectural Safety**:
  - `part` / `part of` support: Never injects imports into `part of` files; safely resolves and injects imports into the parent library file.
  - `AdjacentStrings` merging: Automatically merges multi-line concatenated string literals into a single localization key.
  - `AppStrings` field conversion: Automatically converts `static const String` fields into `static String get` getters to allow dynamic localization lookup.
  - Smart Ignore: Preserves compile-time constants like numbers (`"2026"`), symbols (`"100%"`, `"+91-9876543210"`), default parameter values (`this.title = "Default"`), and `assert` statements.
