# Spec: Secure Runtime Paths and Binary Provenance

> Remote issue: [#2](https://github.com/dphov/omarchy-moergo-companion/issues/2)  
> Status: implemented

## Problem Statement

The plugin currently relies on predictable shared file paths in `/tmp` for IPC, layout caching, and process locking:
1. `Service.qml:13-14` hardcodes `readonly property string jsonFile: "/tmp/glove80_layout.json"`.
2. `keymap-parser/src/bin/watcher.rs:39-52` writes to `/tmp/glove80_layout.tmp` using standard `fs::write` and `fs::rename`.
3. `keymap-parser/src/bin/watcher.rs:12-21` opens `/tmp/glove80_watcher.pid` with `.create(true).truncate(true)` before acquiring an exclusive lock via `flock`.
4. `keymap-parser/src/bin/status.rs:7` writes battery notification state to `/tmp/glove80_battery_notified.json` with standard `fs::write` and `fs::remove_file`.

Because standard filesystem operations follow existing symbolic links and `/tmp` is world-writable with sticky bit semantics, an unprivileged local attacker can pre-create symlinks at these predictable locations pointing to arbitrary user-writable files (e.g., `~/.bashrc`, `~/.ssh/authorized_keys`, or project files). Launching the watcher or status helper will truncate or overwrite those target files without verification.

Furthermore, pre-built 64-bit ELF binaries (`glove80-status`, `moergo-companion-settings`, `moergo-watcher`, `omarchy-moergo-keymap-parser`) are committed directly to `bin/` without verifiable build provenance tying them to the reviewed Rust source in `keymap-parser/`.

## Solution

1. **User-Private Runtime Directory**: Relocate all runtime state, PID locks, temporary files, and layout cache files to a dedicated user-private directory. Use `$XDG_RUNTIME_DIR/omarchy-moergo-companion` when available (guaranteed mode `0700` and owned by the current UID), falling back to a securely created mode `0700` directory under `/tmp` (e.g. `/tmp/omarchy-moergo-${UID}`) or `~/.cache/omarchy/runtime/` with strict UID and symlink checks.
2. **Symlink Rejection & Safe Open Semantics**:
   - Open PID files with `O_NOFOLLOW` (`libc::O_NOFOLLOW`) and without initial truncation. Acquire `flock(LOCK_EX | LOCK_NB)` first; truncate and write PID only after holding the exclusive lock.
   - Reject existing symlinks on all output and state file paths before writing.
3. **Atomic & Secure Temporary File Replacement**:
   - Use secure temporary file creation (`tempfile` crate or `O_TMPFILE` / `O_CREAT | O_EXCL | O_NOFOLLOW` with mode `0600`) inside the user-private runtime directory.
   - Atomically rename the temporary file over the destination file within the same filesystem.
4. **Service Synchronization**: Update `Service.qml` to dynamically resolve the same user-private runtime directory using `Quickshell.env("XDG_RUNTIME_DIR")` with matching fallback logic, or derive the runtime path through a helper invocation/CLI parameter.
5. **Binary Provenance & Build-from-Source**:
   - Remove committed pre-built ELF binaries from git tracking and gitignore `bin/` (or retain them only as published release artifacts).
   - Ensure `install.sh` and `just build` build all four binaries directly from locked source (`Cargo.lock`).
   - Add a CI workflow (`.github/workflows/ci.yml` or `build.yml`) that builds release binaries reproducibly, generates SHA-256 checksums, and verifies build integrity.

## User Stories

1. As a security-conscious user, I want the plugin to store runtime files in `$XDG_RUNTIME_DIR` so that other local users cannot predict or tamper with my layout cache or PID files.
2. As a user on a system without `$XDG_RUNTIME_DIR`, I want the plugin to securely fall back to a mode `0700` user-owned directory so that the plugin functions safely in all desktop environments.
3. As a user, I want file creation to refuse following pre-existing symlinks, so that a malicious process cannot trick the watcher into truncating my personal files.
4. As a user, I want the PID file to be locked before truncation, so that race conditions cannot truncate the file if another process is active.
5. As a user, I want layout JSON updates to use secure atomic replacement, so that the visualizer never reads a partially written file and cannot be hijacked via temporary file symlink injection.
6. As a user, I want battery notification state files to live in the secure runtime directory, so that battery alerts cannot be exploited to overwrite local files.
7. As an Omarchy user, I want `Service.qml` to discover the exact layout file emitted by the watcher without hardcoded `/tmp` paths.
8. As a repository consumer, I want all helper binaries to be compiled from the reviewed Rust source during installation, so that I don't execute untrusted binary blobs checked into git.
9. As a developer, I want CI to build and verify SHA-256 checksums for the binaries, so that binary provenance is transparent and reproducible.
10. As a developer, I want `justfile` and `install.sh` to produce working binaries from source with a clean, repeatable workflow.

## Implementation Decisions

- **Shared Runtime Helper Module**: Introduce a common runtime module in `keymap-parser/src/` (or shared library crate) that resolves the secure runtime directory:
  ```rust
  pub fn get_runtime_dir() -> io::Result<PathBuf>
  ```
  - Priority:
    1. `$XDG_RUNTIME_DIR/omarchy-moergo-companion`
    2. Fallback: `/tmp/omarchy-moergo-{uid}` verified to be owned by current UID, not a symlink, with mode `0o700`.
  - Creates the directory with mode `0o700` (`DirBuilderExt::mode(0o700)`).
- **PID File Hardening (`watcher.rs`)**:
  - Store PID file at `<runtime_dir>/glove80_watcher.pid`.
  - Use `OpenOptionsExt::custom_flags(libc::O_NOFOLLOW)` with `read(true).write(true).create(true)`.
  - Check file metadata: ensure it is a regular file owned by current user.
  - Call `flock(fd, LOCK_EX | LOCK_NB)`.
  - Truncate with `file.set_len(0)` and write PID only *after* acquiring lock.
- **Secure File Writes (`watcher.rs` & `status.rs`)**:
  - Output layout at `<runtime_dir>/glove80_layout.json`.
  - Create temporary files using `tempfile::Builder::new().prefix("glove80_layout_").tempfile_in(&runtime_dir)` or `O_CREAT | O_EXCL | O_NOFOLLOW` with mode `0600`.
  - Atomically persist/rename over target path.
  - Update `status.rs` to store `glove80_battery_notified.json` inside `<runtime_dir>`.
- **QML Path Resolution (`Service.qml`)**:
  - In `Service.qml`:
    ```qml
    readonly property string runtimeDir: {
        var xdg = Quickshell.env("XDG_RUNTIME_DIR");
        if (xdg && xdg.length > 0) {
            return xdg + "/omarchy-moergo-companion";
        }
        return "/tmp/omarchy-moergo-" + Quickshell.env("USER");
    }
    readonly property string jsonFile: runtimeDir + "/glove80_layout.json"
    ```
  - Ensure the watcher ensures the runtime directory exists before writing, and `Service.qml` watches the computed path.
- **ELF Helper Provenance**:
  - Add `bin/` to `.gitignore` (ignoring compiled artifacts).
  - Remove committed ELF files from git tracking (`git rm --cached bin/*`).
  - Update `install.sh` to compile release binaries from `keymap-parser/` directly and place them into `bin/` or install target.
  - Create GitHub Actions workflow (`.github/workflows/ci.yml`) that runs `cargo test`, `cargo build --release`, and outputs SHA-256 sums for built binaries.

## Testing Decisions

- **Security & Symlink Traversal Tests**:
  - Unit/integration test verifying that `acquire_lock` fails cleanly when the PID file path is a pre-created symlink.
  - Integration test verifying that layout writing fails or securely replaces when the target is a symlink, without modifying the symlink target.
  - Test ensuring runtime directory creation sets mode `0700` and validates owner UID.
- **Atomic Replacement Tests**:
  - Test verifying concurrent readers never observe empty or truncated layout JSON.
- **CI / Build Verification**:
  - Automated test in `keymap-parser` ensuring all four binaries build successfully with `cargo test`.
  - Shell script or CI test verifying `install.sh` successfully compiles and installs all binaries from source.

## Out of Scope

- Switching IPC mechanism from file polling/process stdout to D-Bus or Unix domain sockets (the existing file/pipe contract is retained, just moved to a secure private directory).
- Dynamic multi-user session sharing (this is a per-user desktop companion).
- Windows/macOS support (Omarchy is Linux-only).
