"""High-level keymap parsing orchestration."""

import re

from .behaviors import get_zmk_behavior_arity
from .descriptions import describe_key_code
from .json_layout import parse_layout_json
from .layers import extract_layer_name
from .legends import humanize_key_code
from .models import Key, Layer
from .reader import read_file, strip_comments
from .tokenizer import tokenize

_BINDINGS_RE = re.compile(r"bindings\s*=\s*<([^>]*)>")


def parse_layer_bindings(bindings_string: str) -> list[Key]:
    """Convert the contents of one `bindings = <...>` block into a list of Keys."""
    tokens = tokenize(bindings_string)
    keys: list[Key] = []
    i = 0
    while i < len(tokens):
        behavior = tokens[i]
        arity = get_zmk_behavior_arity(behavior)
        key_tokens = [behavior]
        for _ in range(arity):
            i += 1
            if i < len(tokens):
                key_tokens.append(tokens[i])
        raw = " ".join(key_tokens)
        humanized = humanize_key_code(raw)
        title, desc = describe_key_code(raw, humanized)
        keys.append(
            Key(
                raw=raw,
                text=humanized,
                title=title,
                desc=desc,
                is_trans=(behavior in ("&trans", "trans")),
            )
        )
        i += 1
    return keys


def parse_keymap(path: str) -> list[Layer]:
    """Read a ZMK keymap or Glove80 layout-editor JSON file and return its layers."""
    if path.lower().endswith(".json"):
        return parse_layout_json(path)

    source = read_file(path)
    source = strip_comments(source)

    # Only parse bindings inside the keymap { ... } block, matching the original C parser.
    keymap_start = source.find("keymap {")
    if keymap_start == -1:
        return []
    search_region = source[keymap_start:]

    layers: list[Layer] = []
    for match in _BINDINGS_RE.finditer(search_region):
        bindings_content = match.group(1)
        layer_name = extract_layer_name(search_region, match.start())
        keys = parse_layer_bindings(bindings_content)
        layers.append(Layer(name=layer_name, keys=keys))

    return layers
