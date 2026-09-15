use std::fs;
use std::path::PathBuf;
use std::process::Command;

fn project_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn parser_binary() -> PathBuf {
    PathBuf::from(env!("CARGO_BIN_EXE_omarchy-moergo-keymap-parser"))
}

fn parse_fixture(fixture: &str) -> serde_json::Value {
    let output = Command::new(parser_binary())
        .arg(project_root().join("tests").join("fixtures").join(fixture))
        .output()
        .expect("failed to run parser binary");

    assert!(
        output.status.success(),
        "parser exited with non-zero status for {}: stderr: {}",
        fixture,
        String::from_utf8_lossy(&output.stderr)
    );

    serde_json::from_slice(&output.stdout)
        .unwrap_or_else(|e| panic!("invalid JSON for {}: {e}", fixture))
}

fn load_golden(fixture: &str) -> serde_json::Value {
    let path = project_root()
        .join("tests")
        .join("fixtures")
        .join(format!("{fixture}.golden.json"));
    let text = fs::read_to_string(&path).expect("failed to read golden file");
    serde_json::from_str(&text)
        .unwrap_or_else(|e| panic!("invalid golden JSON for {}: {e}", fixture))
}

#[test]
fn sample_keymap_matches_golden() {
    let actual = parse_fixture("sample.keymap");
    let expected = load_golden("sample.keymap");
    assert_eq!(actual, expected);
}

#[test]
fn sample_json_layout_matches_golden() {
    let actual = parse_fixture("sample.json");
    let expected = load_golden("sample.json");
    assert_eq!(actual, expected);
}

#[test]
fn invalid_path_fails_with_nonzero_exit() {
    let output = Command::new(parser_binary())
        .arg("/nonexistent/path/to/keymap.keymap")
        .output()
        .expect("failed to run parser binary");

    assert!(!output.status.success());
}

#[test]
fn missing_argument_fails_with_nonzero_exit() {
    let output = Command::new(parser_binary())
        .output()
        .expect("failed to run parser binary");

    assert!(!output.status.success());
}
