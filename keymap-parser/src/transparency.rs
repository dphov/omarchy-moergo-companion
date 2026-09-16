use crate::models::{Key, Layer};

/// Fill in transparent keys with the first non-transparent key below them.
pub fn resolve_transparent_keys(layers: &mut [Layer]) {
    let mut resolutions: Vec<(usize, usize, Key)> = Vec::new();

    for layer_idx in 0..layers.len() {
        for key_idx in 0..layers[layer_idx].keys.len() {
            if !layers[layer_idx].keys[key_idx].is_trans {
                continue;
            }
            for previous in layers[..layer_idx].iter().rev() {
                if key_idx >= previous.keys.len() {
                    continue;
                }
                let source = &previous.keys[key_idx];
                // Consider a source key valid if it has visible content:
                // text, a glyph, or an explicit color.
                let has_content =
                    !source.text.is_empty() || !source.glyph.is_empty() || !source.color.is_empty();
                if !source.is_trans && has_content {
                    resolutions.push((layer_idx, key_idx, source.clone()));
                    break;
                }
            }
        }
    }

    for (layer_idx, key_idx, source) in resolutions {
        let key = &mut layers[layer_idx].keys[key_idx];
        key.text.clone_from(&source.text);
        key.title.clone_from(&source.title);
        key.desc.clone_from(&source.desc);
        key.glyph.clone_from(&source.glyph);
        key.color.clone_from(&source.color);
        key.text_color.clone_from(&source.text_color);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::Key;

    #[test]
    fn resolves_transparent_keys() {
        let mut layers = vec![
            Layer {
                name: "Base".into(),
                keys: vec![Key::new(
                    "&kp A",
                    "A".into(),
                    "".into(),
                    "".into(),
                    "".into(),
                )],
            },
            Layer {
                name: "Lower".into(),
                keys: vec![Key::new(
                    "&trans",
                    "".into(),
                    "".into(),
                    "".into(),
                    "".into(),
                )],
            },
        ];
        resolve_transparent_keys(&mut layers);
        assert_eq!(layers[1].keys[0].text, "A");
    }
}
