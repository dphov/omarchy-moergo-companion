use std::env;
use std::fs::{self, DirBuilder, OpenOptions};
use std::io::{self, Write};
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use tempfile::NamedTempFile;

/// Name of the companion runtime subdirectory
pub const RUNTIME_SUBDIR: &str = "omarchy-moergo-companion";

/// Layout JSON cache filename
pub const LAYOUT_FILENAME: &str = "glove80_layout.json";

/// Watcher PID lock filename
pub const PID_FILENAME: &str = "glove80_watcher.pid";

/// Battery notification state filename
pub const NOTIFY_STATE_FILENAME: &str = "glove80_battery_notified.json";

/// Returns the current process UID.
pub fn current_uid() -> u32 {
    // SAFETY: libc::getuid is always safe to call as it queries the kernel for the
    // current process UID without preconditions or memory side-effects.
    unsafe { libc::getuid() }
}

/// Validates that `dir` is a directory, not a symlink, owned by the current UID,
/// and has permissions restricted to user-only (mode 0700).
/// If it does not exist, creates it with mode 0700.
pub fn ensure_private_dir(dir: &Path) -> io::Result<()> {
    match fs::symlink_metadata(dir) {
        Ok(meta) => {
            if meta.file_type().is_symlink() {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    format!("Security violation: {:?} is a symlink", dir),
                ));
            }
            if !meta.is_dir() {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    format!("Security violation: {:?} is not a directory", dir),
                ));
            }
            if meta.uid() != current_uid() {
                return Err(io::Error::new(
                    io::ErrorKind::PermissionDenied,
                    format!(
                        "Security violation: {:?} is owned by UID {}, expected {}",
                        dir,
                        meta.uid(),
                        current_uid()
                    ),
                ));
            }

            // Ensure directory permissions are 0700
            let mode = meta.permissions().mode() & 0o777;
            if mode != 0o700 {
                fs::set_permissions(dir, fs::Permissions::from_mode(0o700))?;
            }
            Ok(())
        }
        Err(e) if e.kind() == io::ErrorKind::NotFound => {
            let mut builder = DirBuilder::new();
            builder.mode(0o700);
            builder.create(dir)?;

            // Re-verify immediately after creation to prevent race/symlink swap
            let post_meta = fs::symlink_metadata(dir)?;
            if post_meta.file_type().is_symlink()
                || !post_meta.is_dir()
                || post_meta.uid() != current_uid()
            {
                return Err(io::Error::new(
                    io::ErrorKind::PermissionDenied,
                    format!(
                        "Security violation: newly created {:?} failed validation",
                        dir
                    ),
                ));
            }
            Ok(())
        }
        Err(e) => Err(e),
    }
}

/// Resolves the secure, user-private runtime directory.
///
/// Priority:
/// 1. `$XDG_RUNTIME_DIR/omarchy-moergo-companion`
/// 2. `/tmp/omarchy-moergo-{uid}` (with mode 0700 and symlink rejection)
/// 3. `~/.cache/omarchy/moergo-companion/runtime`
pub fn get_runtime_dir() -> io::Result<PathBuf> {
    let uid = current_uid();

    // 1. Check XDG_RUNTIME_DIR
    if let Some(xdg) = env::var_os("XDG_RUNTIME_DIR") {
        let xdg_path = PathBuf::from(xdg);
        if let Ok(parent_meta) = fs::symlink_metadata(&xdg_path) {
            if !parent_meta.file_type().is_symlink()
                && parent_meta.is_dir()
                && parent_meta.uid() == uid
            {
                let companion_dir = xdg_path.join(RUNTIME_SUBDIR);
                if ensure_private_dir(&companion_dir).is_ok() {
                    return Ok(companion_dir);
                }
            }
        }
    }

    // 2. Fallback to /tmp/omarchy-moergo-{uid}
    let tmp_fallback = PathBuf::from(format!("/tmp/omarchy-moergo-{}", uid));
    if ensure_private_dir(&tmp_fallback).is_ok() {
        return Ok(tmp_fallback);
    }

    // 3. Fallback to ~/.cache/omarchy/moergo-companion/runtime
    if let Some(home) = env::var_os("HOME") {
        let cache_fallback = PathBuf::from(home)
            .join(".cache")
            .join("omarchy")
            .join("moergo-companion")
            .join("runtime");
        if let Some(parent) = cache_fallback.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if ensure_private_dir(&cache_fallback).is_ok() {
            return Ok(cache_fallback);
        }
    }

    Err(io::Error::new(
        io::ErrorKind::Other,
        "Failed to establish a secure mode-0700 user runtime directory",
    ))
}

/// Returns the path to the layout JSON file inside the secure runtime directory.
pub fn get_layout_path() -> io::Result<PathBuf> {
    Ok(get_runtime_dir()?.join(LAYOUT_FILENAME))
}

/// Returns the path to the watcher PID lock file inside the secure runtime directory.
pub fn get_pid_path() -> io::Result<PathBuf> {
    Ok(get_runtime_dir()?.join(PID_FILENAME))
}

/// Returns the path to the battery notification state file inside the secure runtime directory.
pub fn get_notify_state_path() -> io::Result<PathBuf> {
    Ok(get_runtime_dir()?.join(NOTIFY_STATE_FILENAME))
}

/// Safely and atomically writes content to `target` file.
///
/// Refuses to follow symlinks. Generates a temporary file with mode 0600
/// in the same directory and replaces the destination using `rename`.
pub fn atomic_write<P: AsRef<Path>>(target: P, content: &[u8]) -> io::Result<()> {
    let target = target.as_ref();
    let parent = target
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "Target path has no parent"))?;

    ensure_private_dir(parent)?;

    // Reject target if it already exists as a symlink
    if let Ok(meta) = fs::symlink_metadata(target) {
        if meta.file_type().is_symlink() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!("Refusing to write through symlink at {:?}", target),
            ));
        }
    }

    // Create a secure temporary file with unique unguessable name in the same directory
    let mut temp = NamedTempFile::new_in(parent)?;
    temp.write_all(content)?;
    temp.flush()?;

    // Atomically persist/rename over target
    temp.persist(target).map_err(|e| e.error)?;

    Ok(())
}

/// Opens a file with O_NOFOLLOW to strictly prevent following symlinks.
pub fn open_nofollow<P: AsRef<Path>>(
    path: P,
    read: bool,
    write: bool,
    create: bool,
) -> io::Result<fs::File> {
    let path = path.as_ref();

    // Reject explicitly if symlink exists
    if let Ok(meta) = fs::symlink_metadata(path) {
        if meta.file_type().is_symlink() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!("Security violation: {:?} is a symlink", path),
            ));
        }
    }

    let mut opts = OpenOptions::new();
    opts.read(read).write(write).create(create);
    opts.custom_flags(libc::O_NOFOLLOW);
    opts.open(path)
}
