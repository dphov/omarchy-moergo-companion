pub fn tokenize(bindings: &str) -> Vec<&str> {
    bindings.split_whitespace().collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_on_whitespace() {
        assert_eq!(tokenize("&kp A &kp B"), vec!["&kp", "A", "&kp", "B"]);
    }
}
