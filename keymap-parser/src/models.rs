use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, Default, PartialEq)]
pub struct Key {
    pub text: String,
    pub title: String,
    pub desc: String,
    #[serde(rename = "trans")]
    pub is_trans: bool,
    pub glyph: String,
}

impl Key {
    pub fn new(raw: &str, text: String, title: String, desc: String, glyph: String) -> Self {
        Self {
            text,
            title,
            desc,
            is_trans: raw == "&trans" || raw == "trans",
            glyph,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, Default, PartialEq)]
pub struct Layer {
    pub name: String,
    pub keys: Vec<Key>,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default, PartialEq)]
pub struct Layout {
    pub layers: Vec<Layer>,
}
