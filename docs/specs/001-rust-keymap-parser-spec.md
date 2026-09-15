# Spec: Rewrite keymap parser from Python to Rust

> Remote issue: [#1](https://github.com/dphov/omarchy-moergo-companion/issues/1)  
> Status: ready-for-agent

## Problem Statement

The `keymap_parser` package that feeds the Glove80 layer visualizer is currently written in Python. It is invoked by `bin/moergo-watcher` as `python3 -m keymap_parser <keymap_file>` and emits a JSON document that the QML UI consumes.

This creates several problems:

- **Runtime dependency on Python**: Every user must have a compatible Python interpreter available, and the plugin currently pins `requires-python = ">=3.14"`, which is restrictive.
- **Cold-start latency**: Spawning a Python interpreter for every keymap change adds noticeable overhead on lower-powered machines.
- **Deployment friction**: A Python package is harder to ship as a single self-contained Omarchy plugin artifact compared to a native binary.
- **No test coverage**: The parser has no automated tests, making refactors risky.

Rewriting the parser in Rust addresses all of these while preserving the existing QML/watcher integration.

## Solution

Replace the Python `keymap_parser/` package with a Rust crate that compiles to a single native executable. The new binary will be a drop-in replacement for the current CLI invocation and will produce byte-identical JSON output for all supported inputs.

The only consumer-facing change will be that `bin/moergo-watcher` calls the Rust binary instead of `python3 -m keymap_parser`.

## User Stories

1. As an Omarchy user, I want the Glove80 visualizer to work without Python installed, so that the plugin has fewer system dependencies.
2. As a user, I want keymap file changes to be reflected in the visualizer faster, so that the UI feels instantaneous.
3. As a user, I want my existing `.keymap` files to keep working unchanged, so that I do not have to migrate my ZMK layout.
4. As a user, I want exported Glove80 layout-editor `.json` files to keep working unchanged, so that I can switch between keymap formats without reconfiguring the plugin.
5. As a user, I want transparent (`&trans`) keys to still show the resolved key from a lower layer, so that the visualizer remains readable.
6. As a user, I want keycap legends to look identical after the rewrite, so that the visual layout does not change.
7. As a user, I want hover tooltips to show the same title and description after the rewrite, so that the help text remains accurate.
8. As a plugin maintainer, I want the parser to be covered by automated tests, so that I can safely change behavior tables or parsing logic.
9. As a packager, I want the parser to be a single compiled binary, so that installation and distribution are simpler.
10. As a developer, I want the Rust project to follow standard `cargo` conventions, so that it is buildable with the usual toolchain.
11. As a developer, I want the JSON output schema to remain stable, so that the QML UI and watcher do not require changes beyond the executable path.
12. As a user, I want clear error messages when a keymap or JSON file cannot be parsed, so that I can fix the source file.
13. As a developer, I want the build step integrated into the plugin install flow, so that users do not need to run manual commands.
14. As a user, I want the parser to handle C-style comments in `.keymap` files the same way the Python parser does, so that commented-out bindings do not break the visualizer.
15. As a developer, I want the behavior-arity lookup tables to be easy to extend in Rust, so that new ZMK behaviors can be supported without rewriting parsing logic.
16. As a user, I want the parser to continue assuming the standard Glove80 default layout shape, so that the key ordering in the JSON matches the physical matrix.
17. As a maintainer, I want the rewrite to remove the Python `keymap_parser/` package and the `parse_keymap.py` wrapper, so that there is only one implementation to maintain.
18. As a developer, I want the Rust parser to validate its output against golden snapshots, so that regressions in output are caught automatically.
19. As a user, I want the watcher to restart the parser cleanly on file changes, so that transient parse errors do not leave the visualizer stuck.
20. As a packager, I want the Rust crate to live inside the plugin repository, so that the parser and QML UI stay version-locked.

## Implementation Decisions

- **Module replacement**: The `keymap_parser/` Python package and the `parse_keymap.py` wrapper will be removed and replaced by a Rust crate in the same repository root (e.g. `crates/keymap-parser/` or `keymap-parser/`).
- **Binary name**: The compiled binary will be named `omarchy-moergo-keymap-parser` and installed alongside the other helpers in `bin/`.
- **CLI contract**: The binary will accept exactly one positional argument, the path to a `.keymap` or `.json` file, and emit the parsed layout JSON on stdout. It will mirror the current Python CLI contract used by `bin/moergo-watcher`.
- **Output schema preservation**: The emitted JSON will keep the exact shape consumed by QML:
  ```json
  {
    "layers": [
      {
        "name": "Base",
        "keys": [
          { "text": "", "title": "", "desc": "", "trans": false, "glyph": "" }
        ]
      }
    ]
  }
  ```
- **Parser scope**: The Rust parser will preserve the current pragmatic scope: it will strip C-style comments, locate the `keymap { ... }` block, extract each `bindings = <...>` region, tokenize on whitespace, consume behavior arguments using the same arity table, and produce the same `raw` strings that feed legend/description/glyph lookup.
- **Dual format support**: The binary will detect input format by extension. `.json` inputs will be parsed as Glove80 layout-editor exports; everything else will be treated as ZMK `.keymap`.
- **Lookup tables**: Behavior arity, legends, descriptions, glyph categories, and layer-name humanization will be ported to Rust as `const` maps or match arms, preserving the current entries.
- **Transparent key resolution**: After all layers are parsed, a post-processing pass will resolve `&trans` keys by walking down the layer stack at the same key index, identical to the Python `resolve_transparent_keys` function.
- **Watcher update**: `bin/moergo-watcher` will be updated to invoke the new Rust binary path instead of `python3 -m keymap_parser`, and to remove Python-specific error handling that is no longer relevant.
- **Build integration**: The plugin `install.sh` will build the Rust crate in release mode and place the binary in `bin/` (or document that the user must run `cargo build --release` before installing).
- **Error handling**: On failure the binary will exit with a non-zero status and write a human-readable error to stderr; `bin/moergo-watcher` will continue to write an empty `{"layers": []}` JSON file on parse failure to keep the UI in a known state.
- **Encoding**: All text I/O will remain UTF-8.
- **No full C preprocessor**: The rewrite will not implement a full DeviceTree/C preprocessor. It will keep the same comment-stripping and macro assumptions as the Python version.

## Testing Decisions

- **What makes a good test**: Tests will assert observable output (the emitted JSON, legend text, tooltip title/description, glyph category, layer name, and transparent-key resolution) rather than internal data structures or intermediate tokens.
- **Unit tests**: Pure functions such as comment stripping, tokenization, behavior-arity lookup, layer-name extraction/humanization, legend mapping, description lookup, glyph classification, and transparency resolution will each have unit tests.
- **Integration tests**: A `tests/fixtures/` directory will contain sample `.keymap` and `.json` inputs plus expected golden JSON outputs. The test runner will invoke the binary and compare stdout against the golden files.
- **Regression coverage**: Tests will include transparent-key fall-through, multiple layers, Glove80 JSON export round-tripping, C-style comments, and edge cases such as `&none`, `&bootloader`, and Bluetooth-profile bindings.
- **Snapshot style**: Golden JSON files will be compared with strict equality (after normalizing whitespace) so that any accidental output change fails the build.
- **No QML tests**: The visualizer UI is out of scope for parser tests; the contract is the JSON output schema.
- **Prior art**: The plugin currently has no tests, so this will establish the first test suite. The Rust crate will use the standard `cargo test` harness and `serde_json` for assertions.

## Out of Scope

- Rewriting `bin/glove80-status` or `bin/moergo-companion-settings` in Rust.
- Changing the QML UI, `Glove80Matrix.qml`, `KeyCap.qml`, or dashboard behavior.
- Adding support for additional keymap formats beyond ZMK `.keymap` and the Glove80 layout-editor JSON export.
- Implementing a full C/DeviceTree preprocessor (`#include`, `#define`, macro expansion).
- Adding real-time keymap editing or ZMK Studio RPC integration.
- Setting up cross-architecture release builds or CI/CD pipelines (the crate should be cross-compilation friendly, but packaging is not part of this work).
- Changing the watcher polling strategy or replacing it with `inotify`.

## Further Notes

- The current Python parser is intentionally pragmatic: it assumes the keymap follows the standard Glove80 default layout structure and does not attempt to interpret the full ZMK macro system. The Rust rewrite should keep that same pragmatic scope.
- After the rewrite, the plugin will no longer need `python3` for parsing, although `bin/glove80-status` and `bin/moergo-companion-settings` will remain Python scripts for now.
- The README should be updated to remove references to the Python parser and to document the Rust build step.
- Consider pinning the minimum supported Rust version (MSRV) in the crate manifest, for example `1.70` or later, to balance modern features with distribution availability.
