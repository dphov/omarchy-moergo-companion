"""Tokenize a ZMK `bindings = <...>` body into behavior/argument tokens."""


def tokenize(bindings: str) -> list[str]:
    """Split a bindings string on whitespace."""
    return bindings.split()
