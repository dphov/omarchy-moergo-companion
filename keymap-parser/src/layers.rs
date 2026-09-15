pub fn humanize_layer_name(raw: &str) -> String {
    match raw {
        "default_layer" | "default" => "Base".into(),
        "lower_layer" | "lower" => "Lower".into(),
        "magic_layer" | "magic" => "Magic".into(),
        "factory_test_layer" | "factory_test" => "Test".into(),
        _ => {
            let without_suffix = raw.strip_suffix("_layer").unwrap_or(raw);
            title_case_first(&without_suffix.replace('_', " "))
        }
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
