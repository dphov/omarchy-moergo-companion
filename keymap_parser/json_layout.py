"""Adapter for the Glove80 layout editor JSON export format."""

import json

from .descriptions import describe_key_code
from .legends import humanize_key_code
from .models import Key, Layer


def _key_to_raw(key_obj: dict) -> str:
    """Convert a Glove80 JSON key object into the same raw string the .keymap parser uses."""
    behavior = key_obj.get("value", "")
    params = key_obj.get("params", [])
    parts = [behavior]
    for param in params:
        if isinstance(param, dict):
            value = param.get("value", "")
        else:
            value = param
        value = "" if value is None else str(value)
        if value:
            parts.append(value)
    return " ".join(parts)


def parse_layout_json(path: str) -> list[Layer]:
    """Read a Glove80 layout-editor JSON file and return layers."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    layer_names = data.get("layer_names", [])
    layers_data = data.get("layers", [])

    layers: list[Layer] = []
    for idx, layer_keys in enumerate(layers_data):
        name = layer_names[idx] if idx < len(layer_names) else f"Layer {idx + 1}"
        keys: list[Key] = []
        for key_obj in layer_keys:
            raw = _key_to_raw(key_obj)
            humanized = humanize_key_code(raw)
            title, desc = describe_key_code(raw, humanized)
            keys.append(
                Key(
                    raw=raw,
                    text=humanized,
                    title=title,
                    desc=desc,
                    is_trans=(raw in ("&trans", "trans")),
                )
            )
        layers.append(Layer(name=name, keys=keys))

    return layers
