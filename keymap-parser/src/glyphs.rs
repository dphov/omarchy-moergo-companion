const TEXT_BEHAVIORS: &[&str] = &[
    "",
    "&none",
    "none",
    "&trans",
    "trans",
    "&bootloader",
    "&sys_reset",
    "&studio_unlock",
    "&layer_td",
    "&magic",
    "&bt",
    "&out",
    "&to",
    "&mo",
    "&tog",
    "&mt",
    "&lt",
    "&hm",
    "&as",
    "&rgb_ug",
    "&kp",
    "kp",
];

const MODIFIER_CODES: &[&str] = &["LSHFT", "RSHFT", "LCTRL", "RCTRL", "LALT", "RALT"];
const SYSTEM_CODES: &[&str] = &["LGUI", "RGUI"];

pub fn glyph_for_key(raw: &str) -> String {
    let key_code = raw.strip_prefix("&kp ").unwrap_or(raw);
    if SYSTEM_CODES.contains(&key_code) {
        return "system".into();
    }
    if MODIFIER_CODES.contains(&key_code) {
        return "modifier".into();
    }

    let behavior = raw.split_whitespace().next().unwrap_or(raw);
    if !behavior.starts_with('&') || TEXT_BEHAVIORS.contains(&behavior) {
        return String::new();
    }
    if behavior.starts_with("&bt_") || behavior.starts_with("&rgb_ug") {
        return String::new();
    }
    "tap".into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_behaviors_have_no_glyph() {
        assert_eq!(glyph_for_key("&kp A"), "");
        assert_eq!(glyph_for_key("&trans"), "");
    }

    #[test]
    fn modifiers_and_system() {
        assert_eq!(glyph_for_key("&kp LSHFT"), "modifier");
        assert_eq!(glyph_for_key("&kp LGUI"), "system");
    }

    #[test]
    fn unknown_behavior_is_tap() {
        assert_eq!(glyph_for_key("&foo BAR"), "tap");
    }
}
