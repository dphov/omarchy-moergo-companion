"""Rich tooltip title and description generation for ZMK key bindings."""

import re

_BT_PROFILE_RE = re.compile(r"^(&?)bt_(\d+)$")

_OUTPUT_DESCRIPTIONS: dict[str, tuple[str, str]] = {
    "&out OUT_USB": (
        "Output Selection USB",
        "Allows selecting whether keyboard output is sent to the USB or bluetooth connection when both are connected.",
    ),
    "out OUT_USB": (
        "Output Selection USB",
        "Allows selecting whether keyboard output is sent to the USB or bluetooth connection when both are connected.",
    ),
    "&out OUT_BLE": (
        "Output Selection BLE",
        "Allows selecting whether keyboard output is sent to the USB or bluetooth connection when both are connected.",
    ),
    "out OUT_BLE": (
        "Output Selection BLE",
        "Allows selecting whether keyboard output is sent to the USB or bluetooth connection when both are connected.",
    ),
}

_BT_DESCRIPTIONS: dict[str, tuple[str, str]] = {
    "&bt BT_CLR": (
        "Bluetooth Clear Profile",
        "Clears the pairing record for the currently selected Bluetooth profile.",
    ),
    "BT_CLR": (
        "Bluetooth Clear Profile",
        "Clears the pairing record for the currently selected Bluetooth profile.",
    ),
    "&bt BT_CLR_ALL": (
        "Bluetooth Clear All Profiles",
        "Clears all saved Bluetooth pairing records on the keyboard.",
    ),
    "BT_CLR_ALL": (
        "Bluetooth Clear All Profiles",
        "Clears all saved Bluetooth pairing records on the keyboard.",
    ),
}

_FIRMWARE_DESCRIPTIONS: dict[str, tuple[str, str]] = {
    "&bootloader": (
        "Bootloader Mode",
        "Reboots keyboard into UF2 mass-storage bootloader mode for firmware flashing.",
    ),
    "&sys_reset": (
        "System Reset",
        "Performs a hardware reset on the keyboard controller.",
    ),
}

_RGB_DESCRIPTIONS: dict[str, tuple[str, str]] = {
    "RGB_TOG": ("RGB Underglow Toggle", "Toggles underglow RGB lighting on or off."),
    "RGB_EFF": (
        "RGB Underglow Effect",
        "Cycles through underglow RGB animation effects.",
    ),
    "RGB_BRI": ("RGB Brightness Up", "Increases underglow RGB brightness."),
    "RGB_BRD": ("RGB Brightness Down", "Decreases underglow RGB brightness."),
    "RGB_HUI": ("RGB Hue Up", "Increases underglow RGB color hue."),
    "RGB_HUD": ("RGB Hue Down", "Decreases underglow RGB color hue."),
    "RGB_SAI": ("RGB Saturation Up", "Increases underglow RGB color saturation."),
    "RGB_SAD": ("RGB Saturation Down", "Decreases underglow RGB color saturation."),
    "RGB_SPI": ("RGB Speed Up", "Increases animation speed of underglow RGB effects."),
    "RGB_SPD": (
        "RGB Speed Down",
        "Decreases animation speed of underglow RGB effects.",
    ),
}

_KEY_DESCRIPTIONS: dict[str, tuple[str, str]] = {
    "C_BRI_UP": ("Brightness Up", "Increases display brightness."),
    "C_BRI_DN": ("Brightness Down", "Decreases display brightness."),
    "C_VOL_UP": ("Volume Up", "Increases audio output volume."),
    "C_VOL_DN": ("Volume Down", "Decreases audio output volume."),
    "C_MUTE": ("Mute Audio", "Mutes or unmutes audio output."),
    "C_PP": ("Play / Pause", "Toggles media playback."),
    "C_NEXT": ("Next Track", "Skips to the next media track."),
    "C_PREV": ("Previous Track", "Skips to the previous media track."),
    "PSCRN": ("Print Screen", "Captures screenshot of the screen."),
    "PAUSE_BREAK": ("Pause / Break", "Sends standard Pause/Break scancode."),
    "SLCK": ("Scroll Lock", "Toggles scroll lock."),
    "CAPS": ("Caps Lock", "Toggles uppercase lock."),
    "INS": ("Insert", "Toggles insert or overwrite mode."),
    "K_CMENU": ("Context Menu", "Opens application context menu."),
    "BSPC": ("Backspace", "Deletes character before the cursor."),
    "DEL": ("Delete", "Deletes character after the cursor."),
    "RET": ("Enter / Return", "Sends Return / Enter key."),
    "SPACE": ("Space", "Inserts a space character."),
    "TAB": ("Tab", "Advances focus or inserts tab space."),
    "ESC": ("Escape", "Sends Escape key."),
    "PG_UP": ("Page Up", "Scrolls up one page."),
    "PG_DN": ("Page Down", "Scrolls down one page."),
    "HOME": ("Home", "Moves cursor to the start of the line."),
    "END": ("End", "Moves cursor to the end of the line."),
    "LEFT": ("Left Arrow", "Moves cursor left."),
    "RIGHT": ("Right Arrow", "Moves cursor right."),
    "UP": ("Up Arrow", "Moves cursor up."),
    "DOWN": ("Down Arrow", "Moves cursor down."),
    "LSHFT": ("Shift Modifier", "Shift key modifier."),
    "RSHFT": ("Shift Modifier", "Shift key modifier."),
    "LCTRL": ("Control Modifier", "Control key modifier."),
    "RCTRL": ("Control Modifier", "Control key modifier."),
    "LALT": ("Alt Modifier", "Alt / Option key modifier."),
    "RALT": ("Alt Modifier", "Alt / Option key modifier."),
    "LGUI": ("GUI / Super", "Command / Windows / Super key."),
    "RGUI": ("GUI / Super", "Command / Windows / Super key."),
    "KP_NUM": ("Num Lock", "Toggles numeric keypad lock."),
    "KP_ENTER": ("Keypad Enter", "Sends keypad Enter key."),
}


def describe_key_code(raw: str, humanized: str) -> tuple[str, str]:
    """Return a tooltip (title, description) for a raw ZMK binding."""
    if not raw:
        return ("", "")

    if raw in _OUTPUT_DESCRIPTIONS:
        return _OUTPUT_DESCRIPTIONS[raw]

    bt_match = _BT_PROFILE_RE.match(raw)
    if bt_match:
        profile = int(bt_match.group(2)) + 1
        return (
            f"Bluetooth Profile {profile}",
            f"Switches active Bluetooth connection to profile {profile}.",
        )
    if raw in _BT_DESCRIPTIONS:
        return _BT_DESCRIPTIONS[raw]

    if raw.startswith("&magic"):
        return (
            "Magic Layer",
            "Momentary switch to Glove80 hardware configuration and pairing layer.",
        )
    if raw == "&layer_td":
        return (
            "Layer Tap-Dance",
            "Tap to toggle layer, hold to temporarily access the Lower layer.",
        )
    if raw == "&to FACTORY_TEST":
        return ("To Layer: Test", "Switches keyboard layer to the factory test layer.")
    if raw == "&to DEFAULT":
        return (
            "To Layer: Base",
            "Switches keyboard layer back to the default Base layer.",
        )

    if raw in _FIRMWARE_DESCRIPTIONS:
        return _FIRMWARE_DESCRIPTIONS[raw]

    if raw.startswith("&rgb_ug "):
        rgb = raw[8:]
        return _RGB_DESCRIPTIONS.get(rgb, (f"RGB Underglow {rgb}", ""))
    if raw.startswith("rgb_ug "):
        rgb = raw[7:]
        return _RGB_DESCRIPTIONS.get(rgb, (f"RGB Underglow {rgb}", ""))

    key = raw.removeprefix("&kp ")

    if key in _KEY_DESCRIPTIONS:
        return _KEY_DESCRIPTIONS[key]

    if key.startswith("KP_N") and len(key) > 4 and key[4].isdigit():
        return (f"Keypad {key[4]}", f"Types keypad number {key[4]}.")

    if humanized:
        clean = humanized.replace("\n", " ")
        return (f"Key: {clean}", "")

    return ("", "")
