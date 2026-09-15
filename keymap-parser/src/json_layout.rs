use crate::descriptions::describe_key_code;
use crate::glyphs::glyph_for_key;
use crate::legends::humanize_key_code;
use crate::models::{Key, Layer};
use serde::Deserialize;
use std::fs;
use std::io;
use std::path::Path;

#[derive(Debug, Deserialize)]
struct JsonKeyParam {
    #[serde(default)]
    value: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum JsonParam {
    String(String),
    Object(JsonKeyParam),
}

#[derive(Debug, Deserialize)]
struct JsonKey {
    #[serde(default)]
    value: String,
    #[serde(default)]
    params: Vec<JsonParam>,
}

#[derive(Debug, Deserialize)]
struct JsonLayout {
    #[serde(default)]
    layer_names: Vec<String>,
    #[serde(default)]
    layers: Vec<Vec<JsonKey>>,
}

fn key_to_raw(key_obj: &JsonKey) -> String {
    let mut parts: Vec<String> = Vec::with_capacity(key_obj.params.len() + 1);
    parts.push(key_obj.value.clone());
    for param in &key_obj.params {
        let value = match param {
            JsonParam::String(s) => s.clone(),
            JsonParam::Object(o) => o.value.clone().unwrap_or_default(),
        };
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
            let raw = key_to_raw(&key_obj);
            let humanized = humanize_key_code(&raw);
            let (title, desc) = describe_key_code(&raw, &humanized);
            let glyph = glyph_for_key(&raw);
            keys.push(Key::new(&raw, humanized, title, desc, glyph));
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
            "layers": [[{"value": "&kp", "params": [{"value": "A"}]}]]
        }"#;
        let tmp = std::env::temp_dir().join("omp_test_layout.json");
        std::fs::write(&tmp, json).unwrap();
        let layers = parse_layout_json(&tmp).unwrap();
        assert_eq!(layers.len(), 1);
        assert_eq!(layers[0].name, "Base");
        assert_eq!(layers[0].keys[0].text, "A");
        std::fs::remove_file(&tmp).unwrap();
    }
}
