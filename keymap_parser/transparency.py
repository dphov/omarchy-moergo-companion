"""Resolve transparent (`&trans`) keys through the layer stack."""

from .models import Layer


def resolve_transparent_keys(layers: list[Layer]) -> None:
    """Fill in transparent keys with the first non-transparent key below them."""
    for layer_idx, layer in enumerate(layers):
        for key_idx, key in enumerate(layer.keys):
            if not key.is_trans:
                continue
            for previous in reversed(layers[:layer_idx]):
                if key_idx >= len(previous.keys):
                    continue
                source = previous.keys[key_idx]
                if not source.is_trans and source.text:
                    key.text = source.text
                    key.title = source.title
                    key.desc = source.desc
                    break
