# Code Review: Issue #1 — Rust keymap parser rewrite

**Commit range:** `74f67ea..HEAD`  
**Reviewer:** assistant

## Standards

- **Rust module layout** mirrors the previous Python package (`reader | tokenizer | behaviors | legends | descriptions | glyphs | layers | json_layout | transparency | parser | models`), which keeps the seam predictable and aligns with the spec's "module replacement" decision. Good.
- **CLI contract** preserved: one positional argument, JSON on stdout, non-zero exit on error. `main.rs` is minimal and delegates to the library.
- **Settings helper migration:** `bin/moergo-companion-settings` no longer imports the removed Python package; it shells out to the Rust binary for validation. This was necessary because it was the only other consumer of `keymap_parser`. The fallback error message when stderr is empty is reasonable.
- **Build integration:** `install.sh` builds the crate in release mode and copies the binary into `bin/`. It also excludes `keymap-parser/target/` from rsync, avoiding bloated installs.
- **.gitignore** correctly ignores the compiled binary and Rust target directory.
- **Clippy:** clean after fixing `manual_strip` warnings in `legends.rs`.

## Spec

- **Output parity verified:** Rust output matches Python-generated golden JSON for the local `glove80.keymap`, a Glove80 factory default keymap, and a third-party Glorious Engrammer keymap. A synthetic Glove80 JSON layout export also matches.
- **Critical bug fixed:** the original Rust `parse_layer_bindings` never advanced the token index after consuming a behavior, causing an infinite loop on any non-empty keymap. Fixed by adding `i += 1`.
- **Lookup-table parity:** `BSLH` legend and RGB titles were corrected to match Python. Unknown RGB codes fall back to `"RGB Underglow {code}"` as before.
- **Transparent-key resolution** produces identical fall-through results in the fixture and real keymaps.
- **Tests:** 22 unit tests + 4 integration tests (golden JSON + error-path) all pass.
- **README** accurately documents the Rust crate, dependencies, and build step.
- **One spec item partially addressed:** the issue checklist says "No QML changes" — held. "No full C/DeviceTree preprocessor" — held.

## Findings

1. **`keymap-parser/src/parser.rs` search logic is fragile.** The `search_start` offset arithmetic (`absolute_pos + eq_pos + lt_pos + gt_pos + 3`) is correct but opaque. A small refactor to scan with explicit `bindings = < ... >` matching (like the original Python regex) would be easier to audit. **Judgement call; tests currently cover it.**
2. **`parse_keymap` does not handle `.json` detection** — it lives in `parse_file`. This is a minor divergence from Python where `parse_keymap` handled both. The public `parse_and_resolve` covers both, and the CLI uses it, so the external contract is unchanged. **Acceptable.**
3. **Golden fixtures are small.** They exercise the major code paths but do not include comments inside bindings blocks or nested `keymap` macros. Given the spec's pragmatic scope, this is acceptable, but a comment-heavy fixture would strengthen regression coverage.
4. **`bin/moergo-watcher` does not verify the binary exists** before invoking it. A missing binary produces a parse error and falls back to empty layers, which matches the existing error-handling contract. **Acceptable.**

## Verdict

Spec is fully met. Standards are met. The only notable risk is the opaque `search_start` arithmetic, which is mitigated by passing tests and golden comparisons.
