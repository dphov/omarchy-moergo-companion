#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

# Preserve an unmanaged plugin directory before replacing it. The target tree
# must be a plain directory; symlinks are rejected to avoid writing through
# attacker-controlled paths, and non-directory targets are rejected.
target_is_safe() {
  if [[ -L "$TARGET_DIR" ]]; then
    echo "Error: $TARGET_DIR is a symlink; refusing to install through it." >&2
    exit 1
  fi
  if [[ -e "$TARGET_DIR" && ! -d "$TARGET_DIR" ]]; then
    echo "Error: $TARGET_DIR exists but is not a directory; refusing to overwrite." >&2
    exit 1
  fi
}

# Stage a fresh copy of the plugin tree so activation is an atomic mv.
stage_plugin_tree() {
  local staging_dir="${TARGET_DIR}.new.$$"
  rm -rf "$staging_dir"
  mkdir -p "$staging_dir"
  trap 'rm -rf "$staging_dir"' ERR
  rsync -av --delete \
    --exclude=".git" \
    --exclude="keymap-parser/target" \
    --exclude="AGENTS.md" \
    "$SCRIPT_DIR/" "$staging_dir/" >&2
  trap - ERR
  printf '%s\n' "$staging_dir"
}

# Move an existing real plugin directory to a timestamped backup.
preserve_existing_target() {
  if [[ -d "$TARGET_DIR" ]]; then
    local backup_base="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-moergo-companion/backups"
    mkdir -p "$backup_base"
    chmod 700 "$backup_base"
    local backup_dir
    backup_dir="$backup_base/$PLUGIN_ID-$(date +%Y%m%d-%H%M%S)-$$"
    mv "$TARGET_DIR" "$backup_dir"
    printf '%s\n' "$backup_dir"
  fi
}

# Atomically promote the staged tree to the live plugin directory.
activate_staged_tree() {
  local staging_dir="$1"
  mkdir -p "$(dirname "$TARGET_DIR")"
  mv "$staging_dir" "$TARGET_DIR"
}

# Restore a backup when activation leaves the live directory missing or broken.
restore_backup() {
  local backup_dir="$1"
  if [[ -z "$backup_dir" ]]; then
    return 0
  fi
  if [[ ! -d "$TARGET_DIR" ]]; then
    rm -rf "$TARGET_DIR"
    mv "$backup_dir" "$TARGET_DIR"
  fi
}

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

target_is_safe
mkdir -p "$(dirname "$TARGET_DIR")"

staging_dir=""
if ! staging_dir=$(stage_plugin_tree); then
  echo "Error: failed to stage plugin tree." >&2
  exit 1
fi

backup_dir=""
if ! backup_dir=$(preserve_existing_target); then
  echo "Error: failed to preserve existing target." >&2
  rm -rf "$staging_dir"
  exit 1
fi

if ! activate_staged_tree "$staging_dir"; then
  echo "Error: failed to activate staged plugin tree; restoring backup if available." >&2
  rm -rf "$TARGET_DIR"
  restore_backup "$backup_dir"
  exit 1
fi

if [[ -n "${backup_dir:-}" ]]; then
  echo "Previous target preserved at: $backup_dir"
fi

echo "Local development install complete."
echo "To activate, restart the Omarchy shell:"
echo "  omarchy-restart-shell"
