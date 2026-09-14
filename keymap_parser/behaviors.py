"""ZMK behavior arity lookup.

Arity tells the parser how many argument tokens follow a behavior token
inside a `bindings = <...>` block.
"""

_BEHAVIOR_ARITY: dict[str, int] = {
    "&none": 0,
    "&trans": 0,
    "&sys_reset": 0,
    "&bootloader": 0,
    "&studio_unlock": 0,
    "&layer_td": 0,
    "&magic": 2,
}


def get_zmk_behavior_arity(behavior: str) -> int:
    """Return the number of arguments consumed by a behavior token."""
    if behavior in _BEHAVIOR_ARITY:
        return _BEHAVIOR_ARITY[behavior]
    if behavior.startswith(("&bt_", "bt_")):
        return 0
    if behavior.startswith(("&mt", "&lt", "&hm", "&as")):
        return 2
    if behavior.startswith("&") or behavior == "rgb_ug":
        return 1
    return 0
