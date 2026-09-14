"""Key legend rendering: convert raw ZMK key codes to display text."""

_BEHAVIOR_LEGENDS: dict[str, str] = {
    "&none": "",
    "none": "",
    "&trans": "",
    "trans": "",
    "&bootloader": "Boot",
    "&sys_reset": "Reset",
    "&layer_td": "Layer",
}

_BT_FULL_LEGENDS: dict[str, str] = {
    "&bt BT_CLR": "BT\nClr",
    "BT_CLR": "BT\nClr",
    "&bt BT_CLR_ALL": "Clr\nAll",
    "BT_CLR_ALL": "Clr\nAll",
}

_OUTPUT_LEGENDS: dict[str, str] = {
    "&out OUT_USB": "USB",
    "out OUT_USB": "USB",
    "&out OUT_BLE": "BLE",
    "out OUT_BLE": "BLE",
}

_TO_LAYER_LEGENDS: dict[str, str] = {
    "&to FACTORY_TEST": "Test",
    "to FACTORY_TEST": "Test",
    "&to DEFAULT": "Base",
    "to DEFAULT": "Base",
}

_RGB_LEGENDS: dict[str, str] = {
    "RGB_SPI": "RGB\nSpd+",
    "RGB_SPD": "RGB\nSpd-",
    "RGB_SAI": "RGB\nSat+",
    "RGB_SAD": "RGB\nSat-",
    "RGB_HUI": "RGB\nHue+",
    "RGB_HUD": "RGB\nHue-",
    "RGB_BRI": "RGB\nBri+",
    "RGB_BRD": "RGB\nBri-",
    "RGB_TOG": "RGB\nTog",
    "RGB_EFF": "RGB\nEff",
}

_KEY_LEGENDS: dict[str, str] = {
    "KP_NUM": "NumLk",
    "KP_EQUAL": "=",
    "KP_DIVIDE": "/",
    "KP_MULTIPLY": "*",
    "KP_MINUS": "-",
    "KP_PLUS": "+",
    "KP_ENTER": "Enter",
    "KP_DOT": ".",
    "C_BRI_DN": "Bri -",
    "C_BRI_UP": "Bri +",
    "C_PREV": "Prev",
    "C_NEXT": "Next",
    "C_PP": "Play",
    "C_MUTE": "Mute",
    "C_VOL_DN": "Vol -",
    "C_VOL_UP": "Vol +",
    "PAUSE_BREAK": "Pause",
    "PSCRN": "PrtSc",
    "SLCK": "ScrLk",
    "CAPS": "Caps",
    "INS": "Ins",
    "K_CMENU": "Menu",
    "LPAR": "(",
    "RPAR": ")",
    "PRCNT": "%",
    "EQUAL": "+\n=",
    "MINUS": "_\n-",
    "BSLH": "|\n\\",
    "FSLH": "?\n/",
    "SEMI": ":\n;",
    "SQT": "\"\n'",
    "GRAVE": "~\n`",
    "COMMA": "<\n,",
    "DOT": ">\n.",
    "LBKT": "{\n[",
    "RBKT": "}\n]",
    "LSHFT": "Shift",
    "RSHFT": "Shift",
    "LCTRL": "Control",
    "RCTRL": "Control",
    "LALT": "Alt",
    "RALT": "Alt",
    "LGUI": "System",
    "RGUI": "System",
    "BSPC": "Bksp",
    "DEL": "Delete",
    "RET": "Enter",
    "SPACE": "Space",
    "TAB": "Tab",
    "ESC": "Esc",
    "PG_UP": "PgUp",
    "PG_DN": "PgDn",
    "LEFT": "←",
    "RIGHT": "→",
    "UP": "↑",
    "DOWN": "↓",
    "HOME": "Home",
    "END": "End",
}

_NUMBER_SHIFT_SYMBOLS = ")!@#$%^&*("


def _bt_profile_legend(raw: str) -> str:
    prefix_len = 4 if raw.startswith("&") else 3
    profile = int(raw[prefix_len:]) + 1
    return f"BT\n{profile}"


def _number_legend(key: str) -> str:
    digit = int(key[1])
    return f"{_NUMBER_SHIFT_SYMBOLS[digit]}\n{digit}"


def humanize_key_code(raw: str) -> str:
    """Convert a raw ZMK key binding into a short display legend."""
    if raw in _BEHAVIOR_LEGENDS:
        return _BEHAVIOR_LEGENDS[raw]

    if raw.startswith(("&bt_", "bt_")):
        return _bt_profile_legend(raw)
    if raw in _BT_FULL_LEGENDS:
        return _BT_FULL_LEGENDS[raw]
    if raw.startswith("&bt "):
        return raw[4:]

    if raw in _OUTPUT_LEGENDS:
        return _OUTPUT_LEGENDS[raw]
    if raw.startswith("&out "):
        return raw[5:]
    if raw.startswith("out "):
        return raw[4:]

    if raw.startswith("&magic"):
        return "Magic"
    if raw in _TO_LAYER_LEGENDS:
        return _TO_LAYER_LEGENDS[raw]
    if raw.startswith("&to "):
        return raw[4:]
    if raw.startswith("to "):
        return raw[3:]

    if raw.startswith("&rgb_ug "):
        rgb = raw[8:]
        return _RGB_LEGENDS.get(rgb, f"RGB\n{rgb}")
    if raw.startswith("rgb_ug "):
        rgb = raw[7:]
        return _RGB_LEGENDS.get(rgb, f"RGB\n{rgb}")

    key = raw.removeprefix("&kp ")

    if len(key) == 2 and key[0] == "N" and key[1].isdigit():
        return _number_legend(key)

    if key.startswith("KP_N") and len(key) > 4 and key[4].isdigit():
        return key[4]

    return _KEY_LEGENDS.get(key, key)
