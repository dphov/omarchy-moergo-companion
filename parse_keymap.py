#!/usr/bin/env python3
"""Thin wrapper so watcher.sh can run `python3 parse_keymap.py <keymap>`."""

from keymap_parser.__main__ import main

if __name__ == "__main__":
    main()
