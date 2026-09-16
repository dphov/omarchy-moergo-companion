# Issue #2: Spec — Secure Runtime Paths, Symlink Defense, and Binary Provenance

**Remote:** https://github.com/dphov/omarchy-moergo-companion/issues/2  
**Labels:** ready-for-agent, security  
**Local spec:** [docs/specs/002-secure-runtime-paths-and-provenance-spec.md](../specs/002-secure-runtime-paths-and-provenance-spec.md)

## One-line summary

Eliminate predictable `/tmp` paths and symlink vulnerability vectors across `watcher.rs`, `status.rs`, and `Service.qml` by establishing a mode-0700 user-private runtime directory with `O_NOFOLLOW` and atomic tempfile replacement, and enforce build-from-source provenance for all helper binaries.

## Threat Model & Security Researcher Findings

1. **Predictable Shared Path Overwrite / Truncation (CWE-377, CWE-59)**:
   - `Service.qml:13-14` uses `/tmp/glove80_layout.json`.
   - `watcher.rs:39-52` writes `/tmp/glove80_layout.tmp` using ordinary `fs::write` and `fs::rename`.
   - `watcher.rs:12-21` opens `/tmp/glove80_watcher.pid` with `.create(true).truncate(true)` before acquiring `flock`.
   - `status.rs:7` writes `/tmp/glove80_battery_notified.json` using ordinary `fs::write`.
   - **Exploitation**: An unprivileged local user pre-creates symlinks at these predictable paths targeting user-owned sensitive files (e.g. `~/.bashrc`, `~/.ssh/authorized_keys`). When the victim launches the plugin, files are truncated or overwritten.
2. **Binary Provenance Risk**:
   - `bin/` contains pre-compiled ELF binaries without documented build provenance or cryptographic digests tied to reviewed Rust code.

## Seams & Affected Components

1. `keymap-parser/src/lib.rs` / `runtime.rs`: New shared runtime directory resolver providing user-private mode-0700 path resolution.
2. `keymap-parser/src/bin/watcher.rs`: PID file locking and layout output using `O_NOFOLLOW`, pre-lock non-truncating open, and secure atomic tempfile replacement.
3. `keymap-parser/src/bin/status.rs`: Battery notification state file relocation to secure runtime directory.
4. `Service.qml`: Dynamic runtime directory resolution using `Quickshell.env("XDG_RUNTIME_DIR")` with fallback.
5. Repository & Packaging: Remove committed ELF binaries, update `.gitignore`, build from locked source in `install.sh`, add GitHub Actions CI with reproducible builds and SHA-256 digests.

## Implementation checklist

### Phase 1: User-Private Runtime Directory
- [x] Implement `get_runtime_dir()` in Rust (`keymap-parser`):
  - Check `$XDG_RUNTIME_DIR/omarchy-moergo-companion`.
  - Fallback to `/tmp/omarchy-moergo-${UID}` or `~/.cache/omarchy/moergo-companion/runtime`.
  - Ensure directory exists with Unix permissions `0700` (`DirBuilderExt::mode(0o700)`).
  - Verify directory is not a symlink and owned by the current process UID.
- [x] Mirror runtime directory resolution in `Service.qml` (`XDG_RUNTIME_DIR` with matching fallback).

### Phase 2: Symlink Defense & Hardened PID Locking
- [x] Refactor `acquire_lock` in `watcher.rs`:
  - Target `<runtime_dir>/glove80_watcher.pid`.
  - Open with `O_NOFOLLOW` (`OpenOptionsExt::custom_flags(libc::O_NOFOLLOW)`), `read(true).write(true).create(true)`.
  - Do NOT pass `truncate(true)` on open.
  - Acquire `flock(fd, libc::LOCK_EX | libc::LOCK_NB)`.
  - After lock acquisition, verify file is a regular file owned by current user.
  - Truncate file via `file.set_len(0)` and write process PID.

### Phase 3: Secure Atomic Temporary File Replacement
- [x] Add `tempfile` dependency to `keymap-parser/Cargo.toml`.
- [x] Refactor `parse_and_emit` in `watcher.rs`:
  - Target `<runtime_dir>/glove80_layout.json`.
  - Create secure temporary file in `<runtime_dir>` using `tempfile::Builder::new().prefix(".glove80_layout_").tempfile_in(&runtime_dir)`.
  - Write serialized JSON into tempfile.
  - Atomically persist/rename over target path (`tempfile::NamedTempFile::persist`).
- [x] Refactor `status.rs`:
  - Relocate `NOTIFY_STATE_FILE` to `<runtime_dir>/glove80_battery_notified.json`.
  - Use secure tempfile + atomic persist for notification state updates.

### Phase 4: Binary Provenance & Build-from-Source
- [x] Remove committed ELF binaries from git: `git rm bin/glove80-status bin/moergo-companion-settings bin/moergo-watcher bin/omarchy-moergo-keymap-parser`.
- [x] Add `bin/` to `.gitignore`.
- [x] Ensure `install.sh` builds all binaries from `keymap-parser` using `cargo build --release --locked` and installs them to destination.
- [x] Ensure `justfile` has a clean `build` recipe that populates `bin/` when building locally.
- [x] Create `.github/workflows/ci.yml` to compile release binaries from `Cargo.lock` and output SHA-256 checksums.

### Phase 5: Verification & Security Tests
- [x] Add integration test verifying `acquire_lock` fails if PID path is a pre-existing symlink.
- [x] Add integration test verifying atomic layout write rejects symlinks or does not follow symlink targets.
- [x] Add test verifying runtime directory is created with `0700` mode.
- [x] Verify `Service.qml` successfully communicates with `moergo-watcher` in the private directory.
