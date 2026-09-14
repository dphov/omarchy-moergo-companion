"""Layer-name extraction from raw keymap source and humanization."""

_LAYER_NAME_MAP: dict[str, str] = {
    "default_layer": "Base",
    "default": "Base",
    "lower_layer": "Lower",
    "lower": "Lower",
    "magic_layer": "Magic",
    "magic": "Magic",
    "factory_test_layer": "Test",
    "factory_test": "Test",
}


def _title_case_first(text: str) -> str:
    """Capitalize only the first character, matching the C parser output."""
    if not text:
        return text
    return text[0].upper() + text[1:]


def humanize_layer_name(raw: str) -> str:
    """Turn a ZMK layer identifier into a display name."""
    if raw in _LAYER_NAME_MAP:
        return _LAYER_NAME_MAP[raw]
    raw = raw.removesuffix("_layer")
    return _title_case_first(raw.replace("_", " "))


def extract_layer_name(source: str, bindings_pos: int) -> str:
    """Walk backwards from a `bindings = <` site to find the enclosing layer name."""
    brace = source.rfind("{", 0, bindings_pos)
    if brace == -1:
        return "Layer"

    name_end = brace
    while name_end > 0 and source[name_end - 1].isspace():
        name_end -= 1

    name_start = name_end
    while (
        name_start > 0
        and not source[name_start - 1].isspace()
        and source[name_start - 1] not in "{};"
    ):
        name_start -= 1

    raw = source[name_start:name_end]
    return humanize_layer_name(raw) if raw else "Layer"
