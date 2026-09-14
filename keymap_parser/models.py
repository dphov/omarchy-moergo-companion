from dataclasses import dataclass, field


@dataclass
class Key:
    """One parsed key binding."""

    raw: str = ""
    text: str = ""
    title: str = ""
    desc: str = ""
    is_trans: bool = False


@dataclass
class Layer:
    """One keymap layer with its ordered key bindings."""

    name: str = "Layer"
    keys: list[Key] = field(default_factory=list)
