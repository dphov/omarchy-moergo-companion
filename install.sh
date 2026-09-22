#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="dphov/omarchy-moergo-companion"
BIN_DIR="$SCRIPT_DIR/bin"

# Committed SHA-256 digests for release tarballs.
#
# SECURITY: The expected tarball digest lives in this repo snapshot, not on the release page.
# An attacker who replaces the GitHub release asset cannot change the value checked here.
#
# Procedure for adding a new digest (do not edit by hand):
#   1. Check out the exact release tag.
#   2. Run `just release-dry` to build and pack the tarball deterministically.
#   3. Confirm the local tarball digest equals the one published on the GitHub release.
#   4. Copy that digest here, commit it, and push.
declare -A RELEASE_TARBALL_DIGESTS=(
  ["v1.1.1"]="f85b9c542339da29c38baf1f5e3733eb5fa817e02cc73317e5696796c9a84073"
  ["v1.1.2"]="6ee3432399e872607d72649d78693cba644b077bcecfa39c0655aa2fadb6bd21"
  ["v1.1.3"]="a205b9e30a06fad6bdce11bcaf2b8bec3944a32bfeb5398dea5f1b4a04065b5a"
  ["v1.1.4"]="7cd0007e3dd92f917a7887af226ccab06bde4c252d3294caa41beaf584530fc8"
  ["v1.1.5"]="113a277c7ffc4285ea17ebb3c2dc73fd23aa6c2dd83b1478babc7a3236c25894"
  ["v1.1.6"]="a53426a2314306e608f8c6ee0ca1404b2d5a44ec5262aef5224449a268539aeb"
  ["v1.1.7"]="8d4d573d844a3c96bee4db104db9fd4f85d5969844850bf45300505b68989fc6"
  ["v1.1.8"]="281b8ee212d1b7ca3bf0f4e108d1d588f1e619bfe6d33c20ac17e98b91756627"
  ["v1.1.9"]="55f0ab2ed00deac3a37c632b6d4fb028f6c6a3b97e6583b3be5642d3eb0debf7"
  ["v1.2.0"]="14854166afbfe9608247fbef5aa914fb5afd809d5e15f8bbb908b55632e9592c"
)

# Transfer safety limits when downloading release assets.
CURL_MAX_TIME=120
CURL_CONNECT_TIMEOUT=15
CURL_MAX_DOWNLOAD_SIZE="5M"

binaries_present() {
  for binary in omarchy-moergo-keymap-parser moergo-watcher moergo-companion-settings glove80-status; do
    if [[ ! -x "$BIN_DIR/$binary" ]]; then
      return 1
    fi
  done
  return 0
}

get_manifest_version() {
  local manifest="$SCRIPT_DIR/manifest.json"
  if [ ! -f "$manifest" ]; then
    echo "Error: manifest.json not found at $manifest" >&2
    return 1
  fi
  grep -m1 '"version"' "$manifest" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

supported_platform() {
  local arch os
  arch="$(uname -m)"
  os="$(uname -s)"
  if [[ "$os" != "Linux" ]] || [[ "$arch" != "x86_64" ]]; then
    echo "Prebuilt release binaries are only available for Linux x86_64 (current: $os $arch)." >&2
    return 1
  fi
  return 0
}

download_release_binaries() {
  local version="$1"
  local tag="v${version}"
  local tarball="omarchy-moergo-companion-binaries-${tag}.tar.gz"
  local base_url="https://github.com/${REPO}/releases/download/${tag}"
  local expected_digest="${RELEASE_TARBALL_DIGESTS[$tag]:-}"

  if ! supported_platform; then
    return 1
  fi

  if [[ -z "$expected_digest" ]]; then
    echo "Error: no committed digest for release ${tag}. The installer must be updated before this release can be used." >&2
    return 1
  fi

  mkdir -p "$BIN_DIR"
  rm -f "$BIN_DIR"/*

  echo "Downloading verified native helpers from release ${tag}..."
  curl -fsSL \
    --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    --max-filesize "$CURL_MAX_DOWNLOAD_SIZE" \
    -o "$BIN_DIR/${tarball}" "${base_url}/${tarball}" || return 1

  local actual_digest
  actual_digest="$(sha256sum "$BIN_DIR/${tarball}" | awk '{print $1}')"
  if [[ "$actual_digest" != "$expected_digest" ]]; then
    echo "Error: tarball digest mismatch for ${tag}." >&2
    echo "  expected: $expected_digest" >&2
    echo "  actual:   $actual_digest" >&2
    rm -f "$BIN_DIR/${tarball}"
    return 1
  fi
  echo "Tarball digest matches committed value for ${tag}."

  (
    cd "$BIN_DIR"
    set -e
    # The tarball extracts the 4 binaries and internal SHA256SUMS flat into bin/
    tar -xzf "$tarball"
    # Verify the internal binary checksums
    sha256sum -c SHA256SUMS
  ) || return 1

  # Clean up: keep only the extracted binaries and internal manifest
  rm -f "$BIN_DIR/${tarball}"

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
  rm -f "$BIN_DIR"/*
  cp "$SCRIPT_DIR/keymap-parser/target/release/omarchy-moergo-keymap-parser" "$BIN_DIR/"
  cp "$SCRIPT_DIR/keymap-parser/target/release/moergo-watcher" "$BIN_DIR/"
  cp "$SCRIPT_DIR/keymap-parser/target/release/moergo-companion-settings" "$BIN_DIR/"
  cp "$SCRIPT_DIR/keymap-parser/target/release/glove80-status" "$BIN_DIR/"

  (
    cd "$BIN_DIR"
    sha256sum omarchy-moergo-keymap-parser moergo-watcher moergo-companion-settings glove80-status > SHA256SUMS
  )
}

# Parse arguments
force_rebuild=false
ensure_only=false
for arg in "$@"; do
  case "$arg" in
    --rebuild) force_rebuild=true ;;
    --ensure) ensure_only=true ;;
  esac
done

if [[ "$ensure_only" == true ]] && binaries_present; then
  echo "Verified native helpers already present in bin/."
  # Proceed to install/sync only
else
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
