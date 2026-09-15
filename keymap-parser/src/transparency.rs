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
                if !source.is_trans && !source.text.is_empty() {
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
