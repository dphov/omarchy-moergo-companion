#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="dphov/omarchy-moergo-companion"
BIN_DIR="$SCRIPT_DIR/bin"

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' is not installed or not in PATH." >&2
    return 1
  fi
}

get_manifest_version() {
  local manifest="$SCRIPT_DIR/manifest.json"
  if [ ! -f "$manifest" ]; then
    echo "Error: manifest.json not found at $manifest" >&2
    return 1
  fi
  grep -m1 '"version"' "$manifest" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

download_release_binaries() {
  local version="$1"
  local tag="v${version}"
  local base_url="https://github.com/${REPO}/releases/download/${tag}"

  mkdir -p "$BIN_DIR"

  echo "Downloading verified native helpers from release ${tag}..."
  for binary in omarchy-moergo-keymap-parser moergo-watcher moergo-companion-settings glove80-status; do
    curl -fsSL -o "$BIN_DIR/$binary" "${base_url}/${binary}" || return 1
    chmod +x "$BIN_DIR/$binary"
  done

  curl -fsSL -o "$BIN_DIR/SHA256SUMS" "${base_url}/SHA256SUMS" || return 1

  (
    cd "$BIN_DIR"
    sha256sum -c SHA256SUMS
  )

  echo "Release binaries verified successfully."
}

build_from_source() {
  if ! command -v cargo >/dev/null 2>&1; then
    echo "Error: 'cargo' is not installed or not in PATH." >&2
    echo "Please install Rust (https://rustup.rs) to build the native helpers from source." >&2
    return 1
  fi

  echo "Building native Rust helpers from locked source..."
  (
    cd "$SCRIPT_DIR/keymap-parser"
    cargo build --release --locked
  )

  mkdir -p "$BIN_DIR"
  cp "$SCRIPT_DIR/keymap-parser/target/release/omarchy-moergo-keymap-parser" "$BIN_DIR/"
  cp "$SCRIPT_DIR/keymap-parser/target/release/moergo-watcher" "$BIN_DIR/"
  cp "$SCRIPT_DIR/keymap-parser/target/release/moergo-companion-settings" "$BIN_DIR/"
  cp "$SCRIPT_DIR/keymap-parser/target/release/glove80-status" "$BIN_DIR/"

  (
    cd "$BIN_DIR"
    sha256sum glove80-status moergo-companion-settings moergo-watcher omarchy-moergo-keymap-parser > SHA256SUMS
  )
}

# Determine whether to (re)build or download
force_rebuild=false
if [[ "${1:-}" == "--rebuild" ]]; then
  force_rebuild=true
fi

manifest_version=$(get_manifest_version)
echo "Plugin version: $manifest_version"

if [[ "$force_rebuild" == true ]]; then
  build_from_source
else
  if ! download_release_binaries "$manifest_version"; then
    echo "Warning: failed to download release binaries for v${manifest_version}." >&2
    echo "Falling back to building from source..." >&2
    build_from_source
  fi
fi

# If executed outside the Omarchy plugins directory, sync files to target
if [[ "$SCRIPT_DIR" != "$TARGET_DIR" ]]; then
  echo "Installing $PLUGIN_ID to $TARGET_DIR..."
  mkdir -p "$TARGET_DIR"
  rsync -av --delete \
    --exclude=".git" \
    --exclude="keymap-parser/target" \
    --exclude="AGENTS.md" \
    "$SCRIPT_DIR/" "$TARGET_DIR/"
fi

echo "Installation complete."
echo "To activate, restart the Omarchy shell:"
echo "  omarchy-restart-shell"
