#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

echo "Compiling C parser..."
gcc -O2 parser.c -o parser

echo "Installing $PLUGIN_ID to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

# Copy all necessary files
rsync -av --delete --exclude="install.sh" --exclude=".venv" --exclude="parser.c" --exclude=".git" . "$TARGET_DIR/"

echo "Done. The binary 'parser' is included in the plugin folder."
