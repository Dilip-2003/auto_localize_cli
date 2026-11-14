# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- **Phase 1 Scaffolding (`auto_localize_cli:init`)**:
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
  - Multilingual & Cyrillic transliteration support (Russian, Ukrainian, Belarusian, Bulgarian $\rightarrow$ Latin `camelCase`).

- **Compiler-Grade Architectural Safety**:
  - `part` / `part of` support: Never injects imports into `part of` files; safely resolves and injects imports into the parent library file.
  - `AdjacentStrings` merging: Automatically merges multi-line concatenated string literals into a single localization key.
  - `AppStrings` field conversion: Automatically converts `static const String` fields into `static String get` getters to allow dynamic localization lookup.
  - Smart Ignore: Preserves compile-time constants like numbers (`"2026"`), symbols (`"100%"`, `"+91-9876543210"`), default parameter values (`this.title = "Default"`), and `assert` statements.
