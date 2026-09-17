pub fn humanize_layer_name(raw: &str) -> String {
    let s = raw.trim();
    // Strip "layer_" or "layer-" prefix if present
    let s = s
        .strip_prefix("layer_")
        .or_else(|| s.strip_prefix("layer-"))
        .or_else(|| s.strip_prefix("Layer_"))
        .or_else(|| s.strip_prefix("Layer-"))
        .or_else(|| s.strip_prefix("layer "))
        .or_else(|| s.strip_prefix("Layer "))
        .unwrap_or(s);

    // Strip "_layer" or "-layer" suffix if present
    let s = s
        .strip_suffix("_layer")
        .or_else(|| s.strip_suffix("-layer"))
        .or_else(|| s.strip_suffix("_Layer"))
        .or_else(|| s.strip_suffix("-Layer"))
        .or_else(|| s.strip_suffix(" layer"))
        .or_else(|| s.strip_suffix(" Layer"))
        .unwrap_or(s);

    match s.to_ascii_lowercase().as_str() {
        "default" => "Base".into(),
        "lower" => "Lower".into(),
        "magic" => "Magic".into(),
        "factory_test" | "factory test" => "Test".into(),
        _ => title_case_first(&s.replace('_', " ")),
    }
}

fn title_case_first(text: &str) -> String {
    let mut chars = text.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}

/// Walk backwards from a `bindings = <` site to find the enclosing layer name.
pub fn extract_layer_name(source: &str, bindings_pos: usize) -> String {
    let before = &source[..bindings_pos];
    let Some(brace) = before.rfind('{') else {
        return "Layer".into();
    };

    let mut name_end = brace;
    while name_end > 0 && before.as_bytes().get(name_end - 1) == Some(&b' ') {
        name_end -= 1;
    }

    let mut name_start = name_end;
    while name_start > 0 {
        let prev = before.as_bytes()[name_start - 1];
        if prev == b' '
            || prev == b'\t'
            || prev == b'\n'
            || prev == b'\r'
            || prev == b'{'
            || prev == b'}'
            || prev == b';'
        {
            break;
        }
        name_start -= 1;
    }

    let raw = &before[name_start..name_end];
    if raw.is_empty() {
        "Layer".into()
    } else {
        humanize_layer_name(raw)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_layer_names() {
        assert_eq!(humanize_layer_name("default_layer"), "Base");
        assert_eq!(humanize_layer_name("lower"), "Lower");
        assert_eq!(humanize_layer_name("factory_test"), "Test");
        assert_eq!(humanize_layer_name("layer_Factory"), "Factory");
        assert_eq!(humanize_layer_name("layer_Base"), "Base");
        assert_eq!(humanize_layer_name("layer_Lower"), "Lower");
        assert_eq!(humanize_layer_name("layer_Magic"), "Magic");
    }

    #[test]
    fn unknown_layer_names() {
        assert_eq!(humanize_layer_name("nav_layer"), "Nav");
        assert_eq!(humanize_layer_name("num_pad"), "Num pad");
    }

    #[test]
    fn extract_layer_name_finds_name() {
        let source = "lower_layer { bindings = <>; };";
        let pos = source.find("bindings").unwrap();
        assert_eq!(extract_layer_name(source, pos), "Lower");
    }
}
