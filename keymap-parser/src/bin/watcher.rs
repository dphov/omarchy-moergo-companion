use omarchy_moergo_keymap_parser::parse_and_resolve;
use omarchy_moergo_keymap_parser::runtime;
use std::env;
use std::fs::{self, File};
use std::io::{self, Write};
use std::os::unix::fs::MetadataExt;
use std::os::unix::io::AsRawFd;
use std::path::{Path, PathBuf};
use std::process;
use std::thread;
use std::time::Duration;

const POLL_INTERVAL: Duration = Duration::from_secs(1);

/// Acquire an exclusive, non-blocking lock on the PID file.
///
/// Uses O_NOFOLLOW to reject symlinks, acquires an exclusive non-blocking
/// lock first, verifies file ownership, and only truncates and writes PID
/// after the lock is held.
fn acquire_lock() -> io::Result<(File, PathBuf)> {
    let pid_path = runtime::get_pid_path()?;

    // Open without truncate(true) and with O_NOFOLLOW
    let file = runtime::open_nofollow(&pid_path, true, true, true)?;

    let fd = file.as_raw_fd();
    // SAFETY: `fd` is a valid file descriptor obtained from `file`, which remains
    // open in scope. `flock` operates on the open descriptor and does not mutate Rust memory.
    let ret = unsafe { libc::flock(fd, libc::LOCK_EX | libc::LOCK_NB) };
    if ret != 0 {
        return Err(io::Error::last_os_error());
    }

    // Verify file is a regular file owned by current user
    let meta = file.metadata()?;
    if meta.file_type().is_symlink() || !meta.file_type().is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "Security violation: PID file at {:?} is not a regular file",
                pid_path
            ),
        ));
    }
    if meta.uid() != runtime::current_uid() {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!(
                "Security violation: PID file at {:?} is owned by UID {}",
                pid_path,
                meta.uid()
            ),
        ));
    }

    // Truncate only AFTER securing the exclusive lock
    file.set_len(0)?;

    Ok((file, pid_path))
}

fn parse_and_emit<P: AsRef<Path>, Q: AsRef<Path>>(keymap_file: P, output_json: Q) -> bool {
    match parse_and_resolve(keymap_file.as_ref()) {
        Ok(layout) => {
            if let Ok(json) = serde_json::to_string(&layout) {
                if runtime::atomic_write(output_json.as_ref(), json.as_bytes()).is_ok() {
                    return true;
                }
            }
        }
        Err(e) => {
            eprintln!("Parse error: {e}");
        }
    }

    let _ = runtime::atomic_write(output_json.as_ref(), b"{\"layers\":[]}");
    false
}

fn emit_file<P: AsRef<Path>>(path: P) {
    let path = path.as_ref();
    if let Ok(meta) = fs::symlink_metadata(path) {
        if meta.file_type().is_symlink() {
            eprintln!(
                "Security violation: refusing to read layout from symlink at {:?}",
                path
            );
            return;
        }
    }
    if let Ok(bytes) = fs::read(path) {
        let _ = io::stdout().write_all(&bytes);
        let _ = io::stdout().write_all(b"\n");
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() != 2 {
        eprintln!("Usage: {} <keymap_file>", args[0]);
        process::exit(1);
    }

    let keymap_file = &args[1];
    let output_json = runtime::get_layout_path().unwrap_or_else(|e| {
        eprintln!("Failed to resolve secure layout path: {e}");
        process::exit(1);
    });

    let (mut _lock, _pid_path) = match acquire_lock() {
        Ok(res) => res,
        Err(_) => {
            eprintln!("Another glove80 watcher is already running; exiting.");
            process::exit(0);
        }
    };

    if let Err(e) = writeln!(_lock, "{}", process::id()) {
        eprintln!("Failed to write PID file: {e}");
    }
    let _ = _lock.flush();

    let mut last_mtime: Option<std::time::SystemTime> = None;

    loop {
        let mtime = fs::metadata(keymap_file)
            .ok()
            .and_then(|m| m.modified().ok());

        if mtime != last_mtime {
            parse_and_emit(keymap_file, &output_json);
            last_mtime = mtime;
            emit_file(&output_json);
        }

        thread::sleep(POLL_INTERVAL);
    }
}
