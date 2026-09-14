#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

echo "Installing $PLUGIN_ID to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

# Copy all necessary files
rsync -av --delete \
  --exclude="install.sh" \
  --exclude=".venv" \
  --exclude=".git" \
  --exclude="*.pyc" \
  --exclude="__pycache__" \
  --exclude="watcher.sh" \
  . "$TARGET_DIR/"

echo "Done."
