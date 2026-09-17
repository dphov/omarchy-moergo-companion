#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v cargo >/dev/null 2>&1; then
  echo "Error: 'cargo' is not installed or not in PATH." >&2
  echo "Please install Rust (https://rustup.rs) to build the native helpers from source." >&2
  exit 1
fi

echo "Building native Rust helpers from locked source..."
(
  cd "$SCRIPT_DIR/keymap-parser"
  cargo build --release --locked
)

mkdir -p "$SCRIPT_DIR/bin"
cp "$SCRIPT_DIR/keymap-parser/target/release/omarchy-moergo-keymap-parser" "$SCRIPT_DIR/bin/"
cp "$SCRIPT_DIR/keymap-parser/target/release/moergo-watcher" "$SCRIPT_DIR/bin/"
cp "$SCRIPT_DIR/keymap-parser/target/release/moergo-companion-settings" "$SCRIPT_DIR/bin/"
cp "$SCRIPT_DIR/keymap-parser/target/release/glove80-status" "$SCRIPT_DIR/bin/"

# If executed outside the Omarchy plugins directory, sync files to target
if [[ "$SCRIPT_DIR" != "$TARGET_DIR" ]]; then
  echo "Installing $PLUGIN_ID to $TARGET_DIR..."
  mkdir -p "$TARGET_DIR"
  rsync -av --delete \
    --exclude=".git" \
    --exclude="keymap-parser/target" \
    "$SCRIPT_DIR/" "$TARGET_DIR/"
fi

echo "Installation complete."
echo "To activate, restart the Omarchy shell:"
echo "  omarchy-restart-shell"
