# Code Review: Issue #2 — Secure Runtime Paths, Symlink Defense, and Binary Provenance

**Issue:** [#2](https://github.com/dphov/omarchy-moergo-companion/issues/2)  
**Reviewer:** assistant  
**Scope:** Security Researcher Remediation & Binary Provenance

## Standards

- **Rust runtime module:** Encapsulated in `keymap-parser/src/runtime.rs` and cleanly exposed via `lib.rs`. Follows Unix filesystem security idioms (UID checks, symlink detection, restrictive permissions).
- **QML synchronization:** `Service.qml` dynamic binding directly mirrors Rust runtime resolution order (`XDG_RUNTIME_DIR` primary, user-scoped `/tmp` fallback). Tested and confirmed via Quickshell execution.
- **Linters & Formatters:** `cargo fmt --check`, `cargo clippy --locked --all-targets -- -D warnings`, and `qmllint` all pass with zero warnings or errors.
- **Build integrity:** `install.sh` and `justfile` invoke `cargo build --release --locked`, guaranteeing reproducibility from `Cargo.lock`.

## Spec & Security Researcher Findings

- **CWE-377 / CWE-59 Elimination:** All shared, predictable paths in `/tmp` (`/tmp/glove80_layout.json`, `/tmp/glove80_layout.tmp`, `/tmp/glove80_watcher.pid`, `/tmp/glove80_battery_notified.json`) have been migrated to `$XDG_RUNTIME_DIR/omarchy-moergo-companion` with fallback to `/tmp/omarchy-moergo-${UID}`.
- **Mode 0700 & Ownership Enforcement:** The private runtime directory is explicitly created with mode `0700` and validated to be owned by `getuid()`, rejecting symlinks at directory level.
- **Hardened PID Locking:**
  - Opens PID file with `libc::O_NOFOLLOW`.
  - Removed `.truncate(true)` from open options.
  - Exclusively locks file descriptor via `flock(LOCK_EX | LOCK_NB)` prior to truncation.
  - Verifies regular file ownership by current UID post-lock before truncating via `file.set_len(0)` and writing PID.
- **Atomic Tempfile Replacement:**
  - Replaced predictable `.tmp` and standard `fs::write` with `runtime::atomic_write`.
  - Uses `NamedTempFile::new_in` inside the user-private directory (mode `0600`).
  - Pre-checks destination with `symlink_metadata` to refuse overwriting symlinks.
  - Atomically renames over destination.
- **Binary Provenance & Release Pipeline:**
  - Untracked committed ELF binaries from git; updated `.gitignore` to ignore `bin/`.
  - Added `.github/workflows/ci.yml` for pull request / push validation.
  - Added `.github/workflows/release.yml` triggered on Git tags (`v*`) that compiles release binaries from locked source, generates `SHA256SUMS`, and creates a GitHub Release with verification instructions.

## Verification

- **Security Test Suite:** 6 dedicated integration tests in `keymap-parser/tests/security_test.rs` covering:
  - Private directory mode `0700` creation.
  - Symlink directory rejection.
  - Atomic write symlink rejection without altering victim target files.
  - `open_nofollow` symlink rejection.
  - Secure runtime directory resolution.
- **Full Test Suite:** 35 total tests passing across 8 suites.
- **Quickshell Smoke Test:** Verified that `Service.qml` resolves `jsonFile` to `/run/user/1000/omarchy-moergo-companion/glove80_layout.json`, matching Rust `runtime::get_layout_path()`.

## Verdict

Full approval. All security vulnerabilities identified by the researcher are mitigated. Provenance pipeline is established.
