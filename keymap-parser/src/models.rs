use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, Default, PartialEq)]
pub struct Key {
    pub text: String,
    pub title: String,
    pub desc: String,
    #[serde(rename = "trans")]
    pub is_trans: bool,
    pub glyph: String,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub color: String,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub text_color: String,
}

impl Key {
    pub fn new(raw: &str, text: String, title: String, desc: String, glyph: String) -> Self {
        Self::with_details(raw, text, title, desc, glyph, String::new(), String::new())
    }

    pub fn with_color(
        raw: &str,
        text: String,
        title: String,
        desc: String,
        glyph: String,
        color: String,
    ) -> Self {
        Self::with_details(raw, text, title, desc, glyph, color, String::new())
    }

    pub fn with_details(
        raw: &str,
        text: String,
        title: String,
        desc: String,
        glyph: String,
        color: String,
        text_color: String,
    ) -> Self {
        Self {
            text,
            title,
            desc,
            is_trans: raw == "&trans" || raw == "trans",
            glyph,
            color,
            text_color,
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
