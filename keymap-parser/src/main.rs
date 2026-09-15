use omarchy_moergo_keymap_parser::parse_and_resolve;
use std::env;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <keymap_file>", args[0]);
        process::exit(1);
    }

    match parse_and_resolve(&args[1]) {
        Ok(layout) => match serde_json::to_string_pretty(&layout) {
            Ok(json) => println!("{json}"),
            Err(e) => {
                eprintln!("Failed to serialize layout: {e}");
                process::exit(1);
            }
        },
        Err(e) => {
            eprintln!("Parse error: {e}");
            process::exit(1);
        }
    }
}
