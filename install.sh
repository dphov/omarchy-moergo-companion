#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

echo "Building Rust keymap parser..."
(
  cd "$(dirname "$0")/keymap-parser"
  cargo build --release
)

# Ensure the native parser and watcher are available alongside the other helpers.
mkdir -p bin
cp "$(dirname "$0")/keymap-parser/target/release/omarchy-moergo-keymap-parser" bin/
cp "$(dirname "$0")/keymap-parser/target/release/moergo-watcher" bin/
cp "$(dirname "$0")/keymap-parser/target/release/moergo-companion-settings" bin/
cp "$(dirname "$0")/keymap-parser/target/release/glove80-status" bin/

echo "Installing $PLUGIN_ID to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

# Copy all necessary files
rsync -av --delete \
  --exclude="install.sh" \
  --exclude=".git" \
  --exclude="keymap-parser/target" \
  . "$TARGET_DIR/"

echo "Done."
