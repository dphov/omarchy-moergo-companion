use crate::descriptions::describe_key_code;
use crate::glyphs::glyph_for_key;
use crate::legends::humanize_key_code;
use crate::models::{Key, Layer};
use serde::Deserialize;
use serde_json::Value;
use std::fs;
use std::io;
use std::path::Path;

#[derive(Debug, Deserialize)]
struct JsonDecoration {
    #[serde(default)]
    label: Option<String>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    icon: Option<String>,
    #[serde(default)]
    background: Option<String>,
    #[serde(default)]
    color: Option<String>,
}

#[derive(Debug, Deserialize)]
struct JsonKey {
    #[serde(default)]
    value: Value,
    #[serde(default)]
    params: Vec<Value>,
    #[serde(default)]
    decoration: Option<JsonDecoration>,
}

#[derive(Debug, Deserialize)]
struct JsonLayout {
    #[serde(default)]
    layer_names: Vec<String>,
    #[serde(default)]
    layers: Vec<Vec<JsonKey>>,
}

fn json_val_to_str(val: &Value) -> String {
    match val {
        Value::String(s) => s.clone(),
        Value::Number(n) => n.to_string(),
        Value::Bool(b) => b.to_string(),
        Value::Object(map) => {
            if let Some(inner) = map.get("value") {
                json_val_to_str(inner)
            } else {
                String::new()
            }
        }
        _ => String::new(),
    }
}

fn normalize_hex_color(hex: &str) -> String {
    let trimmed = hex.trim();
    if trimmed.starts_with('#') && trimmed.len() == 9 {
        let alpha = &trimmed[7..9];
        let rgb = &trimmed[1..7];
        if alpha.eq_ignore_ascii_case("ff") {
            format!("#{rgb}")
        } else {
            format!("#{alpha}{rgb}")
        }
    } else {
        trimmed.to_string()
    }
}
fn key_to_raw(key_obj: &JsonKey) -> String {
    let behavior = json_val_to_str(&key_obj.value);
    let mut parts: Vec<String> = Vec::with_capacity(key_obj.params.len() + 1);
    if !behavior.is_empty() && behavior != "Custom" {
        parts.push(behavior);
    }
    for param in &key_obj.params {
        let value = json_val_to_str(param);
        if !value.is_empty() {
            parts.push(value);
        }
    }
    parts.join(" ")
}
pub fn parse_layout_json<P: AsRef<Path>>(path: P) -> io::Result<Vec<Layer>> {
    let data: JsonLayout = serde_json::from_reader(fs::File::open(path)?)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

    let mut layers: Vec<Layer> = Vec::with_capacity(data.layers.len());
    for (idx, layer_keys) in data.layers.into_iter().enumerate() {
        let name = data
            .layer_names
            .get(idx)
            .cloned()
            .unwrap_or_else(|| format!("Layer {}", idx + 1));

        let mut keys: Vec<Key> = Vec::with_capacity(layer_keys.len());
        for key_obj in layer_keys {
            let behavior = json_val_to_str(&key_obj.value);
            let is_custom = behavior == "Custom";
            let raw = key_to_raw(&key_obj);
            let mut humanized = humanize_key_code(&raw);
            let (mut title, mut desc) = describe_key_code(&raw, &humanized);
            let mut glyph = glyph_for_key(&raw);
            let mut color = String::new();
            let mut text_color = String::new();
            if let Some(dec) = &key_obj.decoration {
                if let Some(lbl) = &dec.label {
                    let trimmed = lbl.trim();
                    if !trimmed.is_empty() {
                        humanized = trimmed.to_string();
                        if title.is_empty() || title.starts_with("Key: ") {
                            title = humanized.clone();
                        }
                    } else if is_custom {
                        humanized = String::new();
                    }
                } else if is_custom {
                    humanized = String::new();
                }

                if let Some(d) = &dec.description {
                    let trimmed = d.trim();
                    if !trimmed.is_empty() {
                        desc = trimmed.to_string();
                    }
                }
                if let Some(bg) = &dec.background {
                    let normalized = normalize_hex_color(bg);
                    if !normalized.is_empty() {
                        color = normalized;
                    }
                }
                if let Some(c) = &dec.color {
                    let normalized = normalize_hex_color(c);
                    if !normalized.is_empty() {
                        text_color = normalized;
                    }
                }
                if let Some(ic) = &dec.icon {
                    if ic.starts_with("fa-") && ic.len() == 4 && ic.as_bytes()[3].is_ascii_digit() {
                        humanized = ic[3..].to_string();
                        glyph = String::new();
                    } else if ic.starts_with("fa-align-") || ic.contains("angle") || ic.contains("arrow") {
                        glyph = "modifier".into();
                    } else if ic.contains("circle-dot") {
                        glyph = "tap".into();
                    } else if ic.contains("finger") || ic.contains("win") {
                        glyph = "system".into();
                    } else if dec.label.is_some() {
                        glyph = String::new();
                    }
                } else if dec.label.is_some() {
                    glyph = String::new();
                }
            }

            keys.push(Key::with_details(&raw, humanized, title, desc, glyph, color, text_color));
        }
        layers.push(Layer { name, keys });
    }

    Ok(layers)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_minimal_json_layout() {
        let json = r#"{
            "layer_names": ["Base"],
            "layers": [
                [
                    {"value": "&kp", "params": [{"value": "A"}]},
                    {"value": "&tog", "params": [{"value": 1}]},
                    {"value": "&mo", "params": [2]}
                ]
            ]
        }"#;
        let tmp = std::env::temp_dir().join("omp_test_layout.json");
        std::fs::write(&tmp, json).unwrap();
        let layers = parse_layout_json(&tmp).unwrap();
        assert_eq!(layers.len(), 1);
        assert_eq!(layers[0].keys[0].text, "A");
        assert_eq!(layers[0].keys[1].text, "&tog 1");
        assert_eq!(layers[0].keys[2].text, "&mo 2");
        std::fs::remove_file(&tmp).unwrap();
    }
}
