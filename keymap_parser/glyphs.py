"""Map ZMK behaviors to compact SVG glyph categories."""

_TEXT_BEHAVIORS = {
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
}
_MODIFIER_CODES = {"LSHFT", "RSHFT", "LCTRL", "RCTRL", "LALT", "RALT"}
_SYSTEM_CODES = {"LGUI", "RGUI"}


def glyph_for_key(raw: str) -> str:
    """Return the SVG glyph category for a binding, or an empty string for text."""
    key_code = raw.removeprefix("&kp ")
    if key_code in _SYSTEM_CODES:
        return "system"
    if key_code in _MODIFIER_CODES:
        return "modifier"

    behavior = raw.partition(" ")[0]
    if not behavior.startswith("&") or behavior in _TEXT_BEHAVIORS:
        return ""
    if behavior.startswith(("&bt_", "&rgb_ug")):
        return ""
    return "tap"
