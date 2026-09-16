pub fn tokenize(bindings: &str) -> Vec<&str> {
    let mut tokens = Vec::new();
    let bytes = bindings.as_bytes();
    let n = bytes.len();
    let mut i = 0;

    while i < n {
        while i < n
            && (bytes[i] == b' ' || bytes[i] == b'\t' || bytes[i] == b'\n' || bytes[i] == b'\r')
        {
            i += 1;
        }
        if i >= n {
            break;
        }

        let start = i;
        let mut paren_depth = 0;

        while i < n {
            if bytes[i] == b'(' {
                paren_depth += 1;
            } else if bytes[i] == b')' {
                if paren_depth > 0 {
                    paren_depth -= 1;
                }
            } else if paren_depth == 0
                && (bytes[i] == b' ' || bytes[i] == b'\t' || bytes[i] == b'\n' || bytes[i] == b'\r')
            {
                let mut peek = i;
                while peek < n
                    && (bytes[peek] == b' '
                        || bytes[peek] == b'\t'
                        || bytes[peek] == b'\n'
                        || bytes[peek] == b'\r')
                {
                    peek += 1;
                }
                if peek < n && bytes[peek] == b'(' {
                    i = peek;
                    continue;
                }
                break;
            }
            i += 1;
        }

        let token = bindings[start..i].trim();
        if !token.is_empty() {
            tokens.push(token);
        }
    }

    tokens
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_on_whitespace() {
        assert_eq!(tokenize("&kp A &kp B"), vec!["&kp", "A", "&kp", "B"]);
    }

    #[test]
    fn preserves_macro_with_parentheses() {
        assert_eq!(
            tokenize("&LeftPinky (C, LAYER_Enthium) &kp B"),
            vec!["&LeftPinky (C, LAYER_Enthium)", "&kp", "B"]
        );
    }
}
