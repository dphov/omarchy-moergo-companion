use omarchy_moergo_keymap_parser::parse_and_resolve;
use omarchy_moergo_keymap_parser::runtime;
use serde_json::Value;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process;

fn settings_file() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    Path::new(&home)
        .join(".config")
        .join("omarchy")
        .join("glove80-plugin-settings.json")
}

fn load_settings() -> HashMap<String, Value> {
    match fs::read_to_string(settings_file()) {
        Ok(text) => serde_json::from_str(&text).unwrap_or_default(),
        Err(_) => HashMap::new(),
    }
}

fn save_settings(settings: &HashMap<String, Value>) -> io::Result<()> {
    let path = settings_file();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let text = serde_json::to_string_pretty(settings)?;
    runtime::atomic_write(path, text.as_bytes())
}

fn validate_keymap<P: AsRef<Path>>(path: P) -> Result<(), String> {
    let path = path.as_ref();
    if !path.exists() {
        return Err(format!("File not found: {}", path.display()));
    }
    if !path.is_file() {
        return Err(format!("Not a file: {}", path.display()));
    }

    let layout = parse_and_resolve(path).map_err(|e| format!("Failed to parse keymap: {e}"))?;

    if layout.layers.is_empty() || layout.layers.iter().all(|layer| layer.keys.is_empty()) {
        return Err("No valid keymap layers found in file".to_string());
    }

    Ok(())
}

fn print_usage(program: &str) {
    eprintln!("Usage: {program} [--get KEY | --set KEY VALUE | --load]");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let program = args
        .first()
        .map(|s| s.as_str())
        .unwrap_or("moergo-companion-settings");

    if args.len() < 2 || args[1] == "-h" || args[1] == "--help" {
        print_usage(program);
        process::exit(1);
    }

    let cmd = args[1].as_str();
    let mut settings = load_settings();

    match cmd {
        "--load" => {
            println!("{}", serde_json::to_string(&settings).unwrap_or_default());
        }
        "--get" => {
            if args.len() < 3 {
                print_usage(program);
                process::exit(1);
            }
            let key = &args[2];
            let value = settings
                .get(key)
                .cloned()
                .unwrap_or(Value::String(String::new()));
            println!("{}", value.as_str().unwrap_or(""));
        }
        "--set" => {
            if args.len() < 4 {
                print_usage(program);
                process::exit(1);
            }
            let key = args[2].clone();
            let mut value = args[3].clone();

            if key.ends_with("File") || key.ends_with("Path") {
                value = shellexpand::tilde(&value).into_owned();
            }

            if let Err(error) = validate_keymap(&value) {
                println!(
                    "{}",
                    serde_json::json!({
                        "success": false,
                        "error": error,
                        "key": key,
                        "value": value,
                    })
                );
                process::exit(1);
            }

            settings.insert(key.clone(), Value::String(value));
            if let Err(e) = save_settings(&settings) {
                println!(
                    "{}",
                    serde_json::json!({
                        "success": false,
                        "error": format!("Failed to save settings: {e}"),
                        "key": key,
                    })
                );
                process::exit(1);
            }

            let mut output = serde_json::Map::new();
            output.insert("success".to_string(), Value::Bool(true));
            for (k, v) in &settings {
                output.insert(k.clone(), v.clone());
            }
            println!(
                "{}",
                serde_json::to_string(&Value::Object(output)).unwrap_or_default()
            );
        }
        _ => {
            eprintln!("Unknown command: {cmd}");
            print_usage(program);
            process::exit(1);
        }
    }
}
