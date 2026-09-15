use crate::behaviors::behavior_arity;
use crate::descriptions::describe_key_code;
use crate::glyphs::glyph_for_key;
use crate::layers::extract_layer_name;
use crate::legends::humanize_key_code;
use crate::models::{Key, Layer};
use crate::reader::{read_file, strip_comments};
use crate::tokenizer::tokenize;
use crate::transparency::resolve_transparent_keys;
use std::path::Path;

/// Parse a ZMK `.keymap` file into layers.
pub fn parse_keymap<P: AsRef<Path>>(path: P) -> std::io::Result<Vec<Layer>> {
    let source = read_file(path)?;
    let source = strip_comments(&source);

    let Some(keymap_start) = source.find("keymap {") else {
        return Ok(Vec::new());
    };
    let search_region = &source[keymap_start..];

    let mut layers: Vec<Layer> = Vec::new();
    let mut search_start = 0;
    while let Some(pos) = search_region[search_start..].find("bindings") {
        let absolute_pos = search_start + pos;
        // Find `bindings = <`.
        let after_bindings = &search_region[absolute_pos..];
        let Some(eq_pos) = after_bindings.find('=') else {
            search_start = absolute_pos + 1;
            continue;
        };
        let after_eq = &after_bindings[eq_pos + 1..];
        let Some(lt_pos) = after_eq.find('<') else {
            search_start = absolute_pos + 1;
            continue;
        };
        let after_lt = &after_eq[lt_pos + 1..];
        let Some(gt_pos) = after_lt.find('>') else {
            search_start = absolute_pos + 1;
            continue;
        };

        let bindings_content = &after_lt[..gt_pos];
        let layer_name = extract_layer_name(search_region, absolute_pos);
        let keys = parse_layer_bindings(bindings_content);
        layers.push(Layer {
            name: layer_name,
            keys,
        });

        search_start = absolute_pos + eq_pos + lt_pos + gt_pos + 3;
    }

    Ok(layers)
}

fn parse_layer_bindings(bindings_string: &str) -> Vec<Key> {
    let tokens = tokenize(bindings_string);
    let mut keys: Vec<Key> = Vec::new();
    let mut i = 0;

    while i < tokens.len() {
        let behavior = tokens[i];
        let arity = behavior_arity(behavior);
        let mut key_tokens: Vec<&str> = Vec::with_capacity(arity + 1);
        key_tokens.push(behavior);
        for _ in 0..arity {
            i += 1;
            if i < tokens.len() {
                key_tokens.push(tokens[i]);
            }
        }
        let raw = key_tokens.join(" ");
        let humanized = humanize_key_code(&raw);
        let (title, desc) = describe_key_code(&raw, &humanized);
        let glyph = glyph_for_key(&raw);
        keys.push(Key::new(&raw, humanized, title, desc, glyph));
        i += 1;
    }

    keys
}

/// Parse either a `.json` layout file or a `.keymap` file and return layers.
pub fn parse_file<P: AsRef<Path>>(path: P) -> std::io::Result<Vec<Layer>> {
    let path = path.as_ref();
    if path
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.eq_ignore_ascii_case("json"))
        == Some(true)
    {
        crate::json_layout::parse_layout_json(path)
    } else {
        parse_keymap(path)
    }
}

/// Parse a file and resolve transparent keys, returning a `Layout` ready for JSON emission.
pub fn parse_and_resolve<P: AsRef<Path>>(path: P) -> std::io::Result<crate::models::Layout> {
    let mut layers = parse_file(path)?;
    resolve_transparent_keys(&mut layers);
    Ok(crate::models::Layout { layers })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_simple_keymap() {
        let source = r#"
            keymap {
                default_layer {
                    bindings = <&kp A &kp B>;
                };
            };
        "#;
        let tmp = std::env::temp_dir().join("omp_test_simple.keymap");
        std::fs::write(&tmp, source).unwrap();
        let layers = parse_keymap(&tmp).unwrap();
        assert_eq!(layers.len(), 1);
        assert_eq!(layers[0].name, "Base");
        assert_eq!(layers[0].keys.len(), 2);
        assert_eq!(layers[0].keys[0].text, "A");
        std::fs::remove_file(&tmp).unwrap();
    }
}
