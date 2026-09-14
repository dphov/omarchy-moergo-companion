#!/bin/bash
set -euo pipefail
trap 'kill $(jobs -p) 2>/dev/null || true; exit 0' EXIT TERM INT


if [[ -z "${1-}" || -z "${2-}" ]]; then
  echo "Usage: $0 <path_to_keymap> <output_json>"
  exit 1
fi

KEYMAP_FILE="$1"
OUTPUT_JSON="$2"
PARSER_BIN="$(dirname "$0")/parser"
REPO_URL="https://github.com/moergo-sc/glove80-zmk-config.git"
REPO_DIR="$(dirname "$(dirname "$KEYMAP_FILE")")"

# On first run, if the keymap file doesn't exist, download/clone the full official config
if [[ ! -f "$KEYMAP_FILE" ]]; then
  if [[ ! -d "$REPO_DIR" || -z "$(ls -A "$REPO_DIR" 2>/dev/null)" ]]; then
    mkdir -p "$REPO_DIR" 2>/dev/null || true
    git clone --depth 1 "$REPO_URL" "$REPO_DIR" 2>/dev/null || true
  else
    TEMP_DIR="$(mktemp -d)"
    if git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
      cp -rn "$TEMP_DIR"/* "$REPO_DIR"/ 2>/dev/null || true
      cp -rn "$TEMP_DIR"/.[!.]* "$REPO_DIR"/ 2>/dev/null || true
      rm -rf "$TEMP_DIR"
    fi
  fi
fi

# Run initial parse
if [[ -f "$KEYMAP_FILE" ]]; then
  "$PARSER_BIN" "$KEYMAP_FILE" > "$OUTPUT_JSON"
  echo "UPDATED"
fi

# Watch for changes and re-parse
while inotifywait -q -e modify,move_self,close_write "$KEYMAP_FILE" >/dev/null 2>&1; do
  "$PARSER_BIN" "$KEYMAP_FILE" > "$OUTPUT_JSON"
  echo "UPDATED"
done
