pub fn behavior_arity(behavior: &str) -> usize {
    match behavior {
        "&none" | "none" | "&trans" | "trans" | "&sys_reset" | "&bootloader" | "&studio_unlock"
        | "&layer_td" | "&lower" | "lower" => 0,
        "&magic" => 2,
        _ => {
            if behavior.starts_with("&bt_") || behavior.starts_with("bt_") {
                return 0;
            }
            if behavior.starts_with("&mt")
                || behavior.starts_with("&lt")
                || behavior.starts_with("&hm")
                || behavior.starts_with("&as")
            {
                return 2;
            }
            if behavior.starts_with('&') || behavior == "rgb_ug" {
                return 1;
            }
            0
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_arity_behaviors() {
        assert_eq!(behavior_arity("&trans"), 0);
        assert_eq!(behavior_arity("&none"), 0);
        assert_eq!(behavior_arity("&bt_1"), 0);
        assert_eq!(behavior_arity("&lower"), 0);
    }

    #[test]
    fn one_arity_behaviors() {
        assert_eq!(behavior_arity("&kp"), 1);
        assert_eq!(behavior_arity("&mo"), 1);
        assert_eq!(behavior_arity("&to"), 1);
    }

    #[test]
    fn two_arity_behaviors() {
        assert_eq!(behavior_arity("&mt"), 2);
        assert_eq!(behavior_arity("&lt"), 2);
        assert_eq!(behavior_arity("&magic"), 2);
    }
}
