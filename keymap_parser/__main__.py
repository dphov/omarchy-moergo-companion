"""CLI entry point: parse a ZMK keymap and emit JSON."""

import json
import sys

from .parser import parse_keymap
from .transparency import resolve_transparent_keys


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <keymap_file>", file=sys.stderr)
        sys.exit(1)

    layers = parse_keymap(sys.argv[1])
    resolve_transparent_keys(layers)

    output = {
        "layers": [
            {
                "name": layer.name,
                "keys": [
                    {
                        "text": key.text,
                        "title": key.title,
                        "desc": key.desc,
                        "trans": key.is_trans,
                        "glyph": key.glyph,
                    }
                    for key in layer.keys
                ],
            }
            for layer in layers
        ]
    }
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
