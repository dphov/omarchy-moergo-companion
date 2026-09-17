const NUMBER_SHIFT_SYMBOLS: &str = ")!@#$%^&*(";

pub fn humanize_key_code(raw: &str) -> String {
    match raw {
        "" | "&none" | "none" | "&trans" | "trans" => String::new(),
        "&bootloader" => "Boot".into(),
        "&sys_reset" => "Reset".into(),
        "&layer_td" => "Layer".into(),
        "&lower" | "lower" => "Lower".into(),
        _ => {
            if raw.starts_with("&bt_") || raw.starts_with("bt_") {
                return bt_profile_legend(raw);
            }
            match raw {
                "&bt BT_CLR" | "BT_CLR" => "BT\nClr".into(),
                "&bt BT_CLR_ALL" | "BT_CLR_ALL" => "Clr\nAll".into(),
                "&out OUT_USB" | "out OUT_USB" => "USB".into(),
                "&out OUT_BLE" | "out OUT_BLE" => "BLE".into(),
                _ => {
                    if let Some(rest) = raw.strip_prefix("&bt ") {
                        return rest.to_string();
                    }
                    if let Some(rest) = raw.strip_prefix("&out ") {
                        return rest.to_string();
                    }
                    if let Some(rest) = raw.strip_prefix("out ") {
                        return rest.to_string();
                    }
                    if raw.starts_with("&magic") {
                        return "Magic".into();
                    }
                    match raw {
                        "&to FACTORY_TEST" | "to FACTORY_TEST" => "Test".into(),
                        "&to DEFAULT" | "to DEFAULT" => "Base".into(),
                        _ => {
                            if let Some(rest) = raw.strip_prefix("&to ") {
                                return rest.to_string();
                            }
                            if let Some(rest) = raw.strip_prefix("to ") {
                                return rest.to_string();
                            }
                            if let Some(rest) = raw.strip_prefix("&tog ") {
                                return format!("Tog {rest}");
                            }
                            if let Some(rest) = raw.strip_prefix("&mt ") {
                                let parts: Vec<&str> = rest.split_whitespace().collect();
                                if parts.len() >= 2 {
                                    return humanize_key_code(parts[1]);
                                }
                            }
                            if let Some(rest) = raw.strip_prefix("&hm ") {
                                let parts: Vec<&str> = rest.split_whitespace().collect();
                                if parts.len() >= 2 {
                                    return humanize_key_code(parts[1]);
                                }
                            }
                            if let Some(rest) = raw.strip_prefix("&lt ") {
                                let parts: Vec<&str> = rest.split_whitespace().collect();
                                if parts.len() >= 2 {
                                    return humanize_key_code(parts[1]);
                                }
                            }
                            if let Some(paren_start) = raw.find('(') {
                                if let Some(paren_end) = raw[paren_start..].find(')') {
                                    let inside = &raw[paren_start + 1..paren_start + paren_end];
                                    let key_part =
                                        inside.split(',').next().unwrap_or(inside).trim();
                                    if !key_part.is_empty() {
                                        return humanize_key_code(key_part);
                                    }
                                }
                            }
                            if let Some(rest) = raw.strip_prefix("&sticky_key_modtap ") {
                                if rest.contains("RSFT") {
                                    return "RShift".into();
                                }
                                return "Shift".into();
                            }
                            if let Some(rest) = raw.strip_prefix("&thumb ") {
                                let parts: Vec<&str> = rest.split_whitespace().collect();
                                if parts.len() >= 2 {
                                    return humanize_key_code(parts[1]);
                                }
                            }
                            if let Some(rest) = raw.strip_prefix("&space ") {
                                let parts: Vec<&str> = rest.split_whitespace().collect();
                                if parts.len() >= 2 {
                                    return humanize_key_code(parts[1]);
                                }
                                return "Space".into();
                            }
                            if let Some(rest) = raw.strip_prefix("&stumb ") {
                                if rest.contains("Emoji") {
                                    return "Emoji".into();
                                }
                                let parts: Vec<&str> = rest.split_whitespace().collect();
                                if parts.len() >= 2 {
                                    return humanize_key_code(parts[1]);
                                }
                            }
                            match raw {
                                "&thums_up" => return "MousUp".into(),
                                "&thums_down" => return "MousDn".into(),
                                "&parang_left" => return "( <".into(),
                                "&parang_right" => return ") >".into(),
                                _ => {}
                            }
                            if raw.contains("_tap") {
                                return "Tap".into();
                            }
                            if raw.contains("Middy") {
                                return "Ctrl".into();
                            }
                            if raw.contains("Ringy") {
                                return "Alt".into();
                            }
                            if raw.contains("Index")
                                && (raw.contains("Pinky")
                                    || raw.contains("Ringy")
                                    || raw.contains("Middy"))
                            {
                                return "Shift".into();
                            }
                            if let Some(rgb) = raw.strip_prefix("&rgb_ug ") {
                                return rgb_legend(rgb);
                            }
                            if let Some(rgb) = raw.strip_prefix("rgb_ug ") {
                                return rgb_legend(rgb);
                            }
                            let key = raw
                                .strip_prefix("&kp ")
                                .or_else(|| raw.strip_prefix("&kt "))
                                .unwrap_or(raw);
                            if key.len() == 2
                                && key.starts_with('N')
                                && key
                                    .chars()
                                    .nth(1)
                                    .map(|c| c.is_ascii_digit())
                                    .unwrap_or(false)
                            {
                                return number_legend(key);
                            }
                            if key.len() > 4
                                && key.starts_with("KP_N")
                                && key
                                    .chars()
                                    .nth(4)
                                    .map(|c| c.is_ascii_digit())
                                    .unwrap_or(false)
                            {
                                return key[4..5].to_string();
                            }
                            key_legend(key)
                                .map(String::from)
                                .unwrap_or_else(|| key.to_string())
                        }
                    }
                }
            }
        }
    }
}

fn bt_profile_legend(raw: &str) -> String {
    let prefix_len = if raw.starts_with('&') { 4 } else { 3 };
    let profile: usize = raw[prefix_len..].parse().unwrap_or(0);
    format!("BT\n{}", profile + 1)
}

const NUMBER_ROW_DIGIT_INDEX: usize = 1;

fn number_legend(key: &str) -> String {
    let digit = key
        .chars()
        .nth(NUMBER_ROW_DIGIT_INDEX)
        .unwrap()
        .to_digit(10)
        .unwrap() as usize;
    format!(
        "{}\n{}",
        NUMBER_SHIFT_SYMBOLS.chars().nth(digit).unwrap(),
        digit
    )
}

fn rgb_legend(rgb: &str) -> String {
    match rgb {
        "RGB_SPI" => "RGB\nSpd+",
        "RGB_SPD" => "RGB\nSpd-",
        "RGB_SAI" => "RGB\nSat+",
        "RGB_SAD" => "RGB\nSat-",
        "RGB_HUI" => "RGB\nHue+",
        "RGB_HUD" => "RGB\nHue-",
        "RGB_BRI" => "RGB\nBri+",
        "RGB_BRD" => "RGB\nBri-",
        "RGB_TOG" => "RGB\nTog",
        "RGB_EFF" => "RGB\nEff",
        _ => return format!("RGB\n{rgb}"),
    }
    .into()
}

fn key_legend(key: &str) -> Option<&'static str> {
    match key {
        "KP_NUM" => Some("NumLk"),
        "KP_EQUAL" => Some("="),
        "KP_DIVIDE" | "KP_SLASH" => Some("/"),
        "KP_MULTIPLY" => Some("*"),
        "KP_MINUS" => Some("-"),
        "KP_PLUS" => Some("+"),
        "KP_ENTER" => Some("Enter"),
        "KP_DOT" => Some("."),
        "C_BRI_DN" => Some("Bri -"),
        "C_BRI_UP" => Some("Bri +"),
        "C_PREV" => Some("Prev"),
        "C_NEXT" => Some("Next"),
        "C_PP" => Some("Play"),
        "C_MUTE" => Some("Mute"),
        "C_VOL_DN" => Some("Vol -"),
        "C_VOL_UP" => Some("Vol +"),
        "PAUSE_BREAK" | "PAUSE" => Some("Pause"),
        "PSCRN" | "PRINTSCREEN" | "PRINT_SCREEN" => Some("PrtSc"),
        "SLCK" | "SCROLLLOCK" | "SCROLL_LOCK" => Some("ScrLk"),
        "CAPS" => Some("Caps"),
        "INS" | "INSERT" => Some("Ins"),
        "K_CMENU" | "K_APP" | "K_APPLICATION" => Some("Menu"),
        "LPAR" => Some("("),
        "RPAR" => Some(")"),
        "PRCNT" => Some("%"),
        "EQUAL" => Some("+\n="),
        "MINUS" => Some("_\n-"),
        "BSLH" => Some("|\n\\"),
        "FSLH" => Some("?\n/"),
        "SEMI" => Some(":\n;"),
        "SQT" => Some("\"\n'"),
        "GRAVE" => Some("~\n`"),
        "COMMA" => Some("<\n,"),
        "DOT" => Some(">\n."),
        "LBKT" => Some("{\n["),
        "RBKT" => Some("}\n]"),
        "LSHFT" => Some("Shift"),
        "RSHFT" => Some("Shift"),
        "LCTRL" => Some("Ctrl"),
        "RCTRL" => Some("Ctrl"),
        "LALT" => Some("Alt"),
        "RALT" => Some("Alt"),
        "LGUI" => Some("Win"),
        "RGUI" => Some("Win"),
        "BSPC" | "BACKSPACE" => Some("Bksp"),
        "DEL" | "DELETE" => Some("Delete"),
        "RET" | "RETURN" => Some("Enter"),
        "SPACE" => Some("Space"),
        "TAB" => Some("Tab"),
        "ESC" | "ESCAPE" => Some("Esc"),
        "PG_UP" | "PGUP" | "PAGE_UP" => Some("PgUp"),
        "PG_DN" | "PGDN" | "PAGE_DOWN" => Some("PgDn"),
        "LEFT" | "LEFT_ARROW" => Some("←"),
        "RIGHT" | "RIGHT_ARROW" => Some("→"),
        "UP" | "UP_ARROW" => Some("↑"),
        "DOWN" | "DOWN_ARROW" => Some("↓"),
        "HOME" => Some("Home"),
        "END" => Some("End"),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn behavior_legends() {
        assert_eq!(humanize_key_code("&trans"), "");
        assert_eq!(humanize_key_code("&bootloader"), "Boot");
        assert_eq!(humanize_key_code("&sys_reset"), "Reset");
        assert_eq!(humanize_key_code("&lower"), "Lower");
    }

    #[test]
    fn bt_legends() {
        assert_eq!(humanize_key_code("&bt_0"), "BT\n1");
        assert_eq!(humanize_key_code("bt_3"), "BT\n4");
    }

    #[test]
    fn number_legends() {
        assert_eq!(humanize_key_code("&kp N1"), "!\n1");
        assert_eq!(humanize_key_code("&kp N0"), ")\n0");
    }

    #[test]
    fn arrow_legends() {
        assert_eq!(humanize_key_code("&kp LEFT"), "←");
        assert_eq!(humanize_key_code("&kp LEFT_ARROW"), "←");
        assert_eq!(humanize_key_code("&kp UP_ARROW"), "↑");
        assert_eq!(humanize_key_code("&kp DOWN_ARROW"), "↓");
        assert_eq!(humanize_key_code("&kp RIGHT_ARROW"), "→");
        assert_eq!(humanize_key_code("&kp KP_SLASH"), "/");
        assert_eq!(humanize_key_code("&kp PRINTSCREEN"), "PrtSc");
        assert_eq!(humanize_key_code("&kp SCROLLLOCK"), "ScrLk");
        assert_eq!(humanize_key_code("&kp K_APP"), "Menu");
    }
}
