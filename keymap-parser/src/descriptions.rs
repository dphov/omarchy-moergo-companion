use crate::legends::humanize_key_code;

/// Extract custom behavior/macro names from the custom-defined-behaviors text block.
/// Matches device-tree node definitions like `emoji_sunrise: emoji_sunrise { ... }`
/// while excluding standard ZMK behaviors.
pub fn extract_custom_behavior_names(text: &str) -> Vec<String> {
    let mut names = Vec::new();
    for line in text.lines() {
        let line = line.trim();
        // Match `name: name {` style definitions.
        if let Some(colon) = line.find(':') {
            let before = line[..colon].trim();
            if is_behavior_identifier(before) && !is_standard_behavior(before) {
                names.push(before.to_string());
            }
        }
    }
    names.sort();
    names.dedup();
    names
}

fn is_behavior_identifier(s: &str) -> bool {
    !s.is_empty()
        && s.chars().next().map(|c| c.is_ascii_alphabetic() || c == '_').unwrap_or(false)
        && s.chars().all(|c| c.is_ascii_alphanumeric() || c == '_')
}

fn is_standard_behavior(name: &str) -> bool {
    const STANDARD: &[&str] = &[
        "kp", "sk", "sl", "mo", "to", "mt", "lt", "lm", "td", "trans", "none", "out", "bt",
        "rgb_ug", "bootloader", "sys_reset", "magic", "layer_td", "lower", "key_repeat",
        "caps_word", "cap_word", "studio_unlock", "studio_lock",
    ];
    STANDARD.iter().any(|s| *s == name)
}

pub fn describe_key_code(raw: &str, humanized: &str, custom_behaviors: &[String]) -> (String, String) {
    if raw.is_empty() {
        return (String::new(), String::new());
    }

    let behavior_name = raw.strip_prefix('&').unwrap_or(raw).split_whitespace().next().unwrap_or(raw);
    if custom_behaviors.iter().any(|n| n == behavior_name) {
        return (
            format!("Custom Behavior {raw}"),
            "Specify the key behavior by text input, to be used in conjunction with Custom Defined Behaviors.".into(),
        );
    }

    if let Some((title, desc)) = output_description(raw) {
        return (title.into(), desc.into());
    }

    if raw.starts_with("&bt_") || raw.starts_with("bt_") {
        let prefix_len = if raw.starts_with('&') { 4 } else { 3 };
        let profile: usize = raw[prefix_len..].parse().unwrap_or(0);
        return (
            format!("Bluetooth Profile {}", profile + 1),
            format!(
                "Quick-tap to connect to profile {}; double-tap to explicitly disconnect.",
                profile + 1
            ),
        );
    }

    if let Some((title, desc)) = bt_description(raw) {
        return (title.into(), desc.into());
    }

    if raw.starts_with("&magic") {
        return (
            "Magic Layer".into(),
            "Momentary switch to Glove80 hardware configuration and pairing layer.".into(),
        );
    }
    if raw == "&layer_td" {
        return (
            "Layer Tap-Dance".into(),
            "Tap to toggle layer, hold to temporarily access the Lower layer.".into(),
        );
    }
    if raw == "&lower" || raw == "lower" {
        return (
            "Lower Layer".into(),
            "Hold to momentarily switch to Lower layer; double-tap to toggle.".into(),
        );
    }
    if let Some(rest) = raw.strip_prefix("&layer ") {
        let target = rest.trim();
        return (
            format!("Layer: {target}"),
            format!("Hold to momentarily switch to {target} layer; double-tap to toggle."),
        );
    }
    if let Some(rest) = raw.strip_prefix("&sk ") {
        let target = modifier_name(rest.trim());
        return (
            "Sticky Key".into(),
            format!(
                "A Sticky Key stays pressed until another key is pressed. It is often used for \"sticky {target}\". By using a sticky {target}, you don't have to hold the {target} key to write a capital."
            ),
        );
    }
    if let Some(rest) = raw.strip_prefix("&sl ") {
        let target = rest.trim();
        return (
            "Sticky Layer".into(),
            format!(
                "Activates the {target} layer until another key is pressed, then returns to the previous layer."
            ),
        );
    }

    if raw == "&cap_word" || raw == "&caps_word" {
        return (
            "Caps Word".into(),
            "Capitalizes letters until space or punctuation.".into(),
        );
    }
    if raw == "&key_repeat" {
        return (
            "Key Repeat".into(),
            "Repeats the last pressed key.".into(),
        );
    }
    if raw == "&to FACTORY_TEST" {
        return (
            "To Layer: Test".into(),
            "Switches keyboard layer to the factory test layer.".into(),
        );
    }
    if raw == "&to DEFAULT" {
        return (
            "To Layer: Base".into(),
            "Switches keyboard layer back to the default Base layer.".into(),
        );
    }
    if let Some(rest) = raw.strip_prefix("&tog ") {
        let target = rest.trim();
        return (
            format!("Toggle Layer {target}"),
            "Enables a layer until the layer is manually disabled.".into(),
        );
    }

    if let Some((title, desc)) = firmware_description(raw) {
        return (title.into(), desc.into());
    }

    if let Some(rgb) = raw.strip_prefix("&rgb_ug ") {
        return rgb_description(rgb);
    }
    if let Some(rgb) = raw.strip_prefix("rgb_ug ") {
        return rgb_description(rgb);
    }

    if let Some(key) = raw.strip_prefix("&kp ") {
        let name = if humanized.is_empty() { key } else { humanized };
        let clean = name.replace('\n', " ");
        return (
            format!("Key Press {clean}"),
            "Send standard keycode on press and release".into(),
        );
    }

    let key = raw.strip_prefix("&kp ").unwrap_or(raw);

    if let Some((title, desc)) = key_description(key) {
        return (title.into(), desc.into());
    }

    if key.len() > 4
        && key.starts_with("KP_N")
        && key
            .chars()
            .nth(4)
            .map(|c| c.is_ascii_digit())
            .unwrap_or(false)
    {
        let digit = key.chars().nth(4).unwrap();
        return (
            format!("Keypad {digit}"),
            format!("Types keypad number {digit}."),
        );
    }

    if !humanized.is_empty() {
        let clean = humanized.replace('\n', " ");
        return (format!("Key: {clean}"), String::new());
    }

    (String::new(), String::new())
}

fn output_description(raw: &str) -> Option<(&'static str, &'static str)> {
    match raw {
        "&out OUT_USB" | "out OUT_USB" => Some((
            "Output Selection USB",
            "Allows selecting whether keyboard output is sent to the USB or bluetooth connection when both are connected.",
        )),
        "&out OUT_BLE" | "out OUT_BLE" => Some((
            "Output Selection BLE",
            "Allows selecting whether keyboard output is sent to the USB or bluetooth connection when both are connected.",
        )),
        _ => None,
    }
}

fn bt_description(raw: &str) -> Option<(&'static str, &'static str)> {
    match raw {
        "&bt BT_CLR" | "BT_CLR" => Some((
            "Bluetooth Clear Profile",
            "Clears the pairing record for the currently selected Bluetooth profile.",
        )),
        "&bt BT_CLR_ALL" | "BT_CLR_ALL" => Some((
            "Bluetooth Clear All Profiles",
            "Clears all saved Bluetooth pairing records on the keyboard (excluding right hand).",
        )),
        _ => None,
    }
}

fn firmware_description(raw: &str) -> Option<(&'static str, &'static str)> {
    match raw {
        "&bootloader" => Some((
            "Bootloader Mode",
            "Reboots keyboard into UF2 mass-storage bootloader mode for firmware flashing.",
        )),
        "&sys_reset" => Some(("Reset", "Reset this half of the keyboard.")),
        _ => None,
    }
}

fn rgb_description(rgb: &str) -> (String, String) {
    let action = match rgb {
        "RGB_TOG" => "Toggle",
        "RGB_EFF" => "Effect",
        "RGB_BRI" => "Brightness Up",
        "RGB_BRD" => "Brightness Down",
        "RGB_HUI" => "Hue Up",
        "RGB_HUD" => "Hue Down",
        "RGB_SAI" => "Saturation Up",
        "RGB_SAD" => "Saturation Down",
        "RGB_SPI" => "Speed Up",
        "RGB_SPD" => "Speed Down",
        _ => rgb,
    };
    (
        format!("RGB Underglow {action}"),
        "RGB underglow control".into(),
    )
}

fn modifier_name(raw: &str) -> String {
    match raw {
        "LSHFT" | "LSHIFT" => "Left Shift".into(),
        "RSHFT" | "RSHIFT" => "Right Shift".into(),
        "LCTRL" | "LCONTROL" => "Left Control".into(),
        "RCTRL" | "RCONTROL" => "Right Control".into(),
        "LALT" => "Left Alt".into(),
        "RALT" => "Right Alt".into(),
        "LGUI" => "Left GUI".into(),
        "RGUI" => "Right GUI".into(),
        _ => humanize_key_code(raw).replace('\n', " "),
    }
}

fn key_description(key: &str) -> Option<(&'static str, &'static str)> {
    match key {
        "C_BRI_UP" => Some(("Brightness Up", "Increases display brightness.")),
        "C_BRI_DN" => Some(("Brightness Down", "Decreases display brightness.")),
        "C_VOL_UP" => Some(("Volume Up", "Increases audio output volume.")),
        "C_VOL_DN" => Some(("Volume Down", "Decreases audio output volume.")),
        "C_MUTE" => Some(("Mute Audio", "Mutes or unmutes audio output.")),
        "C_PP" => Some(("Play / Pause", "Toggles media playback.")),
        "C_NEXT" => Some(("Next Track", "Skips to the next media track.")),
        "C_PREV" => Some(("Previous Track", "Skips to the previous media track.")),
        "PSCRN" => Some(("Print Screen", "Captures screenshot of the screen.")),
        "PAUSE_BREAK" => Some(("Pause / Break", "Sends standard Pause/Break scancode.")),
        "SLCK" => Some(("Scroll Lock", "Toggles scroll lock.")),
        "CAPS" => Some(("Caps Lock", "Toggles uppercase lock.")),
        "INS" => Some(("Insert", "Toggles insert or overwrite mode.")),
        "K_CMENU" => Some(("Context Menu", "Opens application context menu.")),
        "BSPC" => Some(("Backspace", "Deletes character before the cursor.")),
        "DEL" => Some(("Delete", "Deletes character after the cursor.")),
        "RET" => Some(("Enter / Return", "Sends Return / Enter key.")),
        "SPACE" => Some(("Space", "Inserts a space character.")),
        "TAB" => Some(("Tab", "Advances focus or inserts tab space.")),
        "ESC" => Some(("Escape", "Sends Escape key.")),
        "PG_UP" => Some(("Page Up", "Scrolls up one page.")),
        "PG_DN" => Some(("Page Down", "Scrolls down one page.")),
        "HOME" => Some(("Home", "Moves cursor to the start of the line.")),
        "END" => Some(("End", "Moves cursor to the end of the line.")),
        "LEFT" => Some(("Left Arrow", "Moves cursor left.")),
        "RIGHT" => Some(("Right Arrow", "Moves cursor right.")),
        "UP" => Some(("Up Arrow", "Moves cursor up.")),
        "DOWN" => Some(("Down Arrow", "Moves cursor down.")),
        "LSHFT" => Some(("Shift Modifier", "Shift key modifier.")),
        "RSHFT" => Some(("Shift Modifier", "Shift key modifier.")),
        "LCTRL" => Some(("Control Modifier", "Control key modifier.")),
        "RCTRL" => Some(("Control Modifier", "Control key modifier.")),
        "LALT" => Some(("Alt Modifier", "Alt / Option key modifier.")),
        "RALT" => Some(("Alt Modifier", "Alt / Option key modifier.")),
        "LGUI" => Some(("GUI / Super", "Command / Windows / Super key.")),
        "RGUI" => Some(("GUI / Super", "Command / Windows / Super key.")),
        "KP_NUM" => Some(("Num Lock", "Toggles numeric keypad lock.")),
        "KP_ENTER" => Some(("Keypad Enter", "Sends keypad Enter key.")),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn describes_bt_profile() {
        let (title, desc) = describe_key_code("&bt_2", "BT\n3", &[]);
        assert_eq!(title, "Bluetooth Profile 3");
        assert!(desc.contains("profile 3"));
    }

    #[test]
    fn describes_media_key() {
        let (title, desc) = describe_key_code("&kp C_PP", "Play", &[]);
        assert_eq!(title, "Key Press Play");
        assert!(desc.contains("standard keycode"));
    }

    #[test]
    fn describes_lower_layer() {
        let (title, desc) = describe_key_code("&lower", "Lower", &[]);
        assert_eq!(title, "Lower Layer");
        assert!(desc.contains("Lower"));
    }

    #[test]
    fn describes_custom_behavior() {
        let (title, desc) = describe_key_code("&emoji_sunrise", "", &["emoji_sunrise".into()]);
        assert_eq!(title, "Custom Behavior &emoji_sunrise");
        assert!(desc.contains("Custom Defined Behaviors"));
    }
}
