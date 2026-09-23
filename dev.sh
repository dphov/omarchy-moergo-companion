#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

binaries_present() {
  for binary in omarchy-moergo-keymap-parser moergo-watcher moergo-companion-settings glove80-status; do
    if [[ ! -x "$BIN_DIR/$binary" ]]; then
      return 1
    fi
  done
  return 0
}

if ! binaries_present; then
  echo "Error: local binaries missing in $BIN_DIR/." >&2
  echo "Run 'just build' first to compile the native helpers from source." >&2
  exit 1
fi

echo "Installing $PLUGIN_ID from local build to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"
rsync -av --delete \
  --exclude=".git" \
  --exclude="keymap-parser/target" \
  --exclude="AGENTS.md" \
  "$SCRIPT_DIR/" "$TARGET_DIR/"

echo "Local development install complete."
echo "To activate, restart the Omarchy shell:"
echo "  omarchy-restart-shell"
