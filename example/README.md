# AutoLocalize CLI Example

This directory demonstrates how `auto_localize_cli` is initialized and executed in a Flutter project.

### CLI Usage

In your Flutter project terminal:

```bash
# 1. Initialize localization scaffolding (English default)
dart run auto_localize_cli:init

# Or initialize with your preferred base language (e.g. Russian, Spanish, French, Bengali)
dart run auto_localize_cli:init --locale ru

# 2. Extract strings and update source files bottom-to-top
dart run auto_localize_cli:extract
```

For full documentation, architectural breakdown, and workflow examples, see the [main README](../README.md).
