use crate::descriptions::{describe_key_code, extract_custom_behavior_names};
use crate::glyphs::glyph_for_key;
use crate::legends::humanize_key_code;
use crate::models::{Key, Layer, Layout};
use crate::parser::resolve_layer_references;
use serde::Deserialize;
use serde_json::Value;
use std::fs;
use std::io;
use std::path::Path;

const UUID_LEN: usize = 36;
const UUID_HYPHEN_INDICES: &[usize] = &[8, 13, 18, 23];

fn default_title_from_path<P: AsRef<Path>>(path: P) -> String {
    let path = path.as_ref();
    let stem = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("Glove80 Layout");

    // Strip common leading UUID prefix used by Glove80 downloads:
    // xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx[_-]...
    let s = stem.trim();
    let after_uuid = s
        .char_indices()
        .nth(UUID_LEN)
        .and_then(|(pos, _c)| {
            let prefix = &s[..pos];
            let is_uuid = prefix.len() == UUID_LEN
                && prefix.bytes().enumerate().all(|(i, b)| {
                    b.is_ascii_hexdigit() || UUID_HYPHEN_INDICES.contains(&i) && b == b'-'
                })
                && UUID_HYPHEN_INDICES
                    .iter()
                    .all(|&i| prefix.as_bytes()[i] == b'-');
            if is_uuid {
                let rest = &s[pos..];
                Some(
                    rest.strip_prefix('_')
                        .or_else(|| rest.strip_prefix('-'))
                        .unwrap_or(rest)
                        .trim_start(),
                )
            } else {
                None
            }
        })
        .unwrap_or(s);

    if after_uuid.is_empty() {
        stem.to_string()
    } else {
        after_uuid.to_string()
    }
}

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
struct JsonConfigParam {
    #[serde(default)]
    param_name: Option<String>,
    #[serde(default, rename = "paramName")]
    param_name_alt: Option<String>,
    #[serde(default)]
    value: Option<Value>,
}

#[derive(Debug, Deserialize)]
struct JsonLayout {
    #[serde(default)]
    layer_names: Vec<String>,
    #[serde(default)]
    layers: Vec<Vec<JsonKey>>,
    #[serde(default)]
    title: Option<String>,
    #[serde(default)]
    tags: Vec<String>,
    #[serde(default)]
    notes: Option<String>,
    #[serde(default)]
    custom_defined_behaviors: Option<String>,
    #[serde(default)]
    custom_devicetree: Option<String>,
    #[serde(default)]
    config_parameters: Option<Value>,
    #[serde(default)]
    layout_parameters: Option<Value>,
    #[serde(default, rename = "locale")]
    language: Option<String>,
}

fn format_config_params(value: &Option<Value>) -> String {
    let array = match value {
        Some(Value::Array(arr)) => arr,
        _ => return String::new(),
    };

    array
        .iter()
        .filter_map(|item| {
            let param: JsonConfigParam = serde_json::from_value(item.clone()).ok()?;
            let name = param
                .param_name
                .clone()
                .or_else(|| param.param_name_alt.clone())
                .filter(|s| !s.is_empty())?;
            let value = param
                .value
                .as_ref()
                .map(json_val_to_str)
                .unwrap_or_default();
            if value.is_empty() {
                Some(name)
            } else {
                Some(format!("{name}: {value}"))
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
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
    if trimmed.starts_with('#')
        && trimmed.len() == 9
        && trimmed[1..].bytes().all(|b| b.is_ascii_hexdigit())
    {
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
pub fn parse_layout_json<P: AsRef<Path>>(path: P) -> io::Result<Layout> {
    let path = path.as_ref();
    let data: JsonLayout = serde_json::from_reader(fs::File::open(path)?)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

    let title = data
        .title
        .clone()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| default_title_from_path(path));

    let config_parameters_text = format_config_params(&data.config_parameters);
    let layout_parameters_text = format_config_params(&data.layout_parameters);
    let combined_config = if config_parameters_text.is_empty() {
        layout_parameters_text
    } else if layout_parameters_text.is_empty() {
        config_parameters_text
    } else {
        format!("{config_parameters_text}\n{layout_parameters_text}")
    };

    let custom_defined_behaviors_text = data.custom_defined_behaviors.clone().unwrap_or_default();
    let custom_behaviors = extract_custom_behavior_names(&custom_defined_behaviors_text);

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
            let (mut title, mut desc) = describe_key_code(&raw, &humanized, &custom_behaviors);
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
                        if is_custom && !title.starts_with("Custom Behavior") {
                            title = format!("Custom Behavior {raw}");
                        }
                        let generic = "Specify the key behavior by text input, to be used in conjunction with Custom Defined Behaviors.";
                        if desc.trim() == trimmed || !desc.contains(generic) {
                            desc = format!("{generic}\n\n{trimmed}");
                        } else {
                            desc = format!("{desc}\n\n{trimmed}");
                        }
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
                    let trimmed = ic.trim();
                    if trimmed.starts_with("fa-")
                        && trimmed.len() == 4
                        && trimmed.as_bytes()[3].is_ascii_digit()
                    {
                        humanized = trimmed[3..].to_string();
                        glyph = String::new();
                    } else if !trimmed.is_empty() {
                        glyph = trimmed.to_string();
                    }
                } else if dec.label.is_some() {
                    glyph = String::new();
                }
            }

            keys.push(Key::with_details(
                &raw, humanized, title, desc, glyph, color, text_color,
            ));
        }
        layers.push(Layer { name, keys });
    }

    resolve_layer_references(&mut layers);

    Ok(Layout {
        layers,
        title,
        tags: data.tags,
        notes: data.notes.unwrap_or_default(),
        custom_defined_behaviors: custom_defined_behaviors_text,
        custom_devicetree: data.custom_devicetree.unwrap_or_default(),
        config_parameters: combined_config,
        language: data.language.unwrap_or_default(),
        custom_behaviors,
    })
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
        let layout = parse_layout_json(&tmp).unwrap();
        assert_eq!(layout.layers.len(), 1);
        assert_eq!(layout.layers[0].keys[0].text, "A");
        assert_eq!(layout.layers[0].keys[1].text, "Tog 1");
        assert_eq!(layout.layers[0].keys[2].text, "&mo 2");
        std::fs::remove_file(&tmp).unwrap();
    }

    #[test]
    fn normalize_hex_color_does_not_panic_on_non_ascii() {
        assert_eq!(normalize_hex_color("#aaaaa€"), "#aaaaa€");
        assert_eq!(normalize_hex_color("#123456ff"), "#123456");
        assert_eq!(normalize_hex_color("#12345680"), "#80123456");
    }
}
