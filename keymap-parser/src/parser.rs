use crate::behaviors::behavior_arity;
use crate::descriptions::describe_key_code;
use crate::glyphs::glyph_for_key;
use crate::descriptions::extract_custom_behavior_names;
use crate::layers::extract_layer_name;
use crate::legends::humanize_key_code;
use crate::models::{Key, Layer, Layout};
use crate::reader::{read_file, strip_comments};
use crate::tokenizer::tokenize;
use crate::transparency::resolve_transparent_keys;
use std::path::Path;

/// Parse a ZMK `.keymap` file into layers.
pub fn parse_keymap<P: AsRef<Path>>(path: P) -> std::io::Result<Layout> {
    let source = read_file(&path)?;
    let stripped = strip_comments(&source);
    let title = title_from_keymap_source(&source, &path);
    let custom_defined_behaviors = extract_custom_behaviors(&source);
    let custom_behaviors = extract_custom_behavior_names(&custom_defined_behaviors);

    let Some(keymap_start) = stripped.find("keymap {") else {
        return Ok(Layout {
            layers: Vec::new(),
            title,
            tags: Vec::new(),
            notes: String::new(),
            custom_defined_behaviors,
            custom_devicetree: String::new(),
            config_parameters: String::new(),
            language: language_from_keymap_source(&source),
            custom_behaviors,
        });
    };
    let search_region = &stripped[keymap_start..];

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
        let keys = parse_layer_bindings(bindings_content, &custom_behaviors);
        layers.push(Layer {
            name: layer_name,
            keys,
        });

        search_start = absolute_pos + eq_pos + lt_pos + gt_pos + 3;
    }

    resolve_layer_references(&mut layers);

    Ok(Layout {
        layers,
        title,
        tags: Vec::new(),
        notes: String::new(),
        custom_defined_behaviors,
        custom_devicetree: String::new(),
        config_parameters: String::new(),
        language: language_from_keymap_source(&source),
        custom_behaviors,
    })
}

pub fn resolve_layer_references(layers: &mut [Layer]) {
    let names: Vec<String> = layers.iter().map(|l| l.name.clone()).collect();
    for layer in layers.iter_mut() {
        for key in layer.keys.iter_mut() {
            if let Some(new_title) = resolve_layer_in_title(&key.raw, &key.title, &names) {
                key.title = new_title;
            }
        }
    }
}

fn resolve_layer_in_title(raw: &str, title: &str, names: &[String]) -> Option<String> {
    let parts: Vec<&str> = raw.split_whitespace().collect();
    if parts.len() < 2 {
        return None;
    }
    let behavior = parts[0];
    let target = parts[1];
    if !matches!(behavior, "&tog" | "&mo" | "&to" | "&sl") {
        return None;
    }
    let idx: usize = target.parse().ok()?;
    let name = names.get(idx)?;
    let label = format!("{idx} {name}");
    Some(title.replacen(target, &label, 1))
}

fn title_from_keymap_source<P: AsRef<Path>>(source: &str, path: P) -> String {
    let path = path.as_ref();

    // Look for a title in C-style comments like:
    // // Title: My Layout
    // // Sunaku's Keymap v52 -- "Glorious Engrammer"
    for line in source.lines() {
        let trimmed = line.trim();
        if let Some(body) = trimmed.strip_prefix("//") {
            let body = body.trim();
            if let Some(t) = body.strip_prefix("Title:") {
                let t = t.trim();
                if !t.is_empty() {
                    return t.to_string();
                }
            }
        }
    }

    path.file_stem()
        .and_then(|s| s.to_str())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Glove80 Layout".to_string())
}

fn language_from_keymap_source(source: &str) -> String {
    // Look for a language hint in C-style comments like:
    // // Language: en-US
    for line in source.lines() {
        let trimmed = line.trim();
        if let Some(body) = trimmed.strip_prefix("//") {
            let body = body.trim();
            if let Some(l) = body.strip_prefix("Language:") {
                let l = l.trim();
                if !l.is_empty() {
                    return l.to_string();
                }
            }
        }
    }
    String::new()
}

fn extract_custom_behaviors(source: &str) -> String {
    // Capture any custom macro/behavior definitions between the end of
    // includes and the start of the device tree root (`/ {`). This mirrors
    // how the Glove80 layout editor exposes "Custom Defined Behaviors".
    let Some(dt_root) = source.find("/ {") else {
        return String::new();
    };
    let prefix = &source[..dt_root];
    let Some(include_end) = prefix.rfind("#include") else {
        return String::new();
    };
    let Some(line_end) = prefix[include_end..].find('\n') else {
        return String::new();
    };
    let slice = &prefix[include_end + line_end..];
    let cleaned = slice.trim();
    if cleaned.is_empty() {
        String::new()
    } else {
        cleaned.to_string()
    }
}

fn parse_layer_bindings(bindings_string: &str, custom_behaviors: &[String]) -> Vec<Key> {
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
        let (title, desc) = describe_key_code(&raw, &humanized, custom_behaviors);
        let glyph = glyph_for_key(&raw);
        keys.push(Key::new(&raw, humanized, title, desc, glyph));
        i += 1;
    }

    keys
}

/// Parse either a `.json` layout file or a `.keymap` file and return a Layout.
pub fn parse_file<P: AsRef<Path>>(path: P) -> std::io::Result<Layout> {
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
pub fn parse_and_resolve<P: AsRef<Path>>(path: P) -> std::io::Result<Layout> {
    let path = path.as_ref();
    let mut layout = parse_file(path)?;
    resolve_transparent_keys(&mut layout.layers);
    Ok(layout)
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
        let layout = parse_keymap(&tmp).unwrap();
        assert_eq!(layout.layers.len(), 1);
        assert_eq!(layout.layers[0].name, "Base");
        assert_eq!(layout.layers[0].keys.len(), 2);
        assert_eq!(layout.layers[0].keys[0].text, "A");
        std::fs::remove_file(&tmp).unwrap();
    }
}
