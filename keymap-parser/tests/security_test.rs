use omarchy_moergo_keymap_parser::runtime;
use std::fs;
use std::os::unix::fs::{symlink, PermissionsExt};
use tempfile::tempdir;

#[test]
fn test_ensure_private_dir_creates_with_0700() {
    let tmp = tempdir().unwrap();
    let target = tmp.path().join("sub_runtime");

    assert!(!target.exists());
    runtime::ensure_private_dir(&target).expect("Must create directory");

    assert!(target.is_dir());
    let meta = fs::symlink_metadata(&target).unwrap();
    let mode = meta.permissions().mode() & 0o777;
    assert_eq!(mode, 0o700, "Runtime directory must have mode 0700");
}

#[test]
fn test_ensure_private_dir_rejects_symlink() {
    let tmp = tempdir().unwrap();
    let real_dir = tmp.path().join("real_dir");
    fs::create_dir(&real_dir).unwrap();

    let symlink_path = tmp.path().join("symlink_dir");
    symlink(&real_dir, &symlink_path).unwrap();

    let res = runtime::ensure_private_dir(&symlink_path);
    assert!(res.is_err(), "Must reject symlink directory");
    let err_msg = res.unwrap_err().to_string();
    assert!(err_msg.contains("symlink"));
}

#[test]
fn test_atomic_write_creates_file_and_content() {
    let tmp = tempdir().unwrap();
    let runtime_dir = tmp.path().join("runtime");
    runtime::ensure_private_dir(&runtime_dir).unwrap();

    let target_file = runtime_dir.join("test_file.json");
    let content = b"{\"hello\":\"world\"}";

    runtime::atomic_write(&target_file, content).expect("Atomic write should succeed");
    assert!(target_file.is_file());
    assert_eq!(fs::read(&target_file).unwrap(), content);
}

#[test]
fn test_atomic_write_rejects_symlink_and_protects_target() {
    let tmp = tempdir().unwrap();
    let runtime_dir = tmp.path().join("runtime");
    runtime::ensure_private_dir(&runtime_dir).unwrap();

    // Create a sensitive "target" file that an attacker wants to overwrite
    let sensitive_file = tmp.path().join("victim_secret.txt");
    fs::write(&sensitive_file, b"TOP_SECRET_DO_NOT_OVERWRITE").unwrap();

    // Pre-create symlink in runtime dir pointing to sensitive file
    let layout_symlink = runtime_dir.join("glove80_layout.json");
    symlink(&sensitive_file, &layout_symlink).unwrap();

    // Attempt atomic write to the symlink path
    let res = runtime::atomic_write(&layout_symlink, b"{\"malicious\":true}");
    assert!(
        res.is_err(),
        "atomic_write MUST refuse to write through a symlink"
    );

    // Verify victim file was NEVER modified or truncated
    let sensitive_content = fs::read(&sensitive_file).unwrap();
    assert_eq!(
        sensitive_content, b"TOP_SECRET_DO_NOT_OVERWRITE",
        "Target file must not be modified or truncated"
    );
}

#[test]
fn test_open_nofollow_rejects_symlink() {
    let tmp = tempdir().unwrap();
    let sensitive_file = tmp.path().join("target.txt");
    fs::write(&sensitive_file, b"DATA").unwrap();

    let symlink_path = tmp.path().join("symlink.pid");
    symlink(&sensitive_file, &symlink_path).unwrap();

    let res = runtime::open_nofollow(&symlink_path, true, true, false);
    assert!(res.is_err(), "open_nofollow MUST reject opening a symlink");

    // Verify target file was not modified
    assert_eq!(fs::read(&sensitive_file).unwrap(), b"DATA");
}

#[test]
fn test_get_runtime_dir_resolves_and_validates() {
    let dir = runtime::get_runtime_dir().expect("Must successfully resolve a secure runtime dir");
    assert!(dir.is_dir());

    let meta = fs::symlink_metadata(&dir).unwrap();
    assert!(!meta.file_type().is_symlink());
    let mode = meta.permissions().mode() & 0o777;
    assert_eq!(mode, 0o700);
}
