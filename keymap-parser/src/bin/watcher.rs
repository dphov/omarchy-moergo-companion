use omarchy_moergo_keymap_parser::parse_and_resolve;
use std::env;
use std::fs::{self, File, OpenOptions};
use std::io::{self, Write};
use std::os::unix::io::AsRawFd;
use std::path::Path;
use std::process;
use std::thread;
use std::time::Duration;

const POLL_INTERVAL: Duration = Duration::from_secs(1);
const PID_FILE: &str = "/tmp/glove80_watcher.pid";

/// Acquire an exclusive, non-blocking lock on the PID file.
/// If another watcher already holds the lock, this instance exits cleanly.
fn acquire_lock() -> io::Result<File> {
    let file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(PID_FILE)?;

    let fd = file.as_raw_fd();
    let ret = unsafe { libc::flock(fd, libc::LOCK_EX | libc::LOCK_NB) };
    if ret != 0 {
        return Err(io::Error::last_os_error());
    }

    Ok(file)
}

fn write_empty<P: AsRef<Path>>(path: P) -> io::Result<()> {
    fs::write(path.as_ref(), b"{\"layers\":[]}")
}

fn parse_and_emit<P: AsRef<Path>>(keymap_file: P, output_json: P) -> bool {
    match parse_and_resolve(keymap_file.as_ref()) {
        Ok(layout) => {
            let tmp = output_json.as_ref().with_extension("tmp");
            if let Ok(json) = serde_json::to_string(&layout) {
                if fs::write(&tmp, json).is_ok() {
                    let _ = fs::rename(&tmp, output_json.as_ref());
                    return true;
                }
            }
        }
        Err(e) => {
            eprintln!("Parse error: {e}");
        }
    }

    let _ = write_empty(output_json);
    false
}

fn emit_file<P: AsRef<Path>>(path: P) {
    if let Ok(bytes) = fs::read(path.as_ref()) {
        let _ = io::stdout().write_all(&bytes);
        let _ = io::stdout().write_all(b"\n");
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: {} <keymap_file> <output_json>", args[0]);
        process::exit(1);
    }

    let keymap_file = &args[1];
    let output_json = &args[2];

    let mut _lock = match acquire_lock() {
        Ok(f) => f,
        Err(_) => {
            eprintln!("Another glove80 watcher is already running; exiting.");
            process::exit(0);
        }
    };

    if let Err(e) = writeln!(_lock, "{}", process::id()) {
        eprintln!("Failed to write PID file: {e}");
    }

    let mut last_mtime: Option<std::time::SystemTime> = None;

    loop {
        let mtime = fs::metadata(keymap_file)
            .ok()
            .and_then(|m| m.modified().ok());

        if mtime != last_mtime {
            parse_and_emit(keymap_file, output_json);
            last_mtime = mtime;
            emit_file(output_json);
        }

        thread::sleep(POLL_INTERVAL);
    }
}
