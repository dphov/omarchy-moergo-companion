# Issue #1: Spec — Rewrite keymap parser from Python to Rust

**Remote:** https://github.com/dphov/omarchy-moergo-companion/issues/1  
**Labels:** ready-for-agent  
**Local spec:** [docs/specs/001-rust-keymap-parser-spec.md](../specs/001-rust-keymap-parser-spec.md)

## One-line summary

Replace the Python `keymap_parser/` package with a Rust crate that produces a drop-in native binary, keeping the same CLI contract and JSON output schema for the QML visualizer.

## Seams

1. `bin/moergo-watcher` invocation: `python3 -m keymap_parser <file>` → `bin/omarchy-moergo-keymap-parser <file>`.
2. JSON output consumed by `MoErgoCompanion.qml` and `components/*` remains unchanged.

## Implementation checklist

- [ ] Scaffold Rust crate (`Cargo.toml`, `src/main.rs`, `src/lib.rs`).
- [ ] Port comment stripping and `keymap { ... }` / `bindings = <...>` extraction.
- [ ] Port behavior arity, legend, description, glyph, and layer-name lookup tables.
- [ ] Port `.json` Glove80 layout-editor parser.
- [ ] Port transparent-key (`&trans`) fall-through resolver.
- [ ] Emit identical JSON output schema on stdout.
- [ ] Update `bin/moergo-watcher` to call the Rust binary.
- [ ] Wire Rust build into `install.sh`.
- [ ] Remove Python `keymap_parser/` package and `parse_keymap.py`.
- [ ] Add unit and golden JSON integration tests.
- [ ] Update README to document the Rust build step.

## Notes

- No QML changes.
- No full C/DeviceTree preprocessor.
- `bin/glove80-status` and `bin/moergo-companion-settings` stay Python for now.
