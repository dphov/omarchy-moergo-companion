#!/bin/bash
set -euo pipefail

PLUGIN_ID="dphov.omarchy-moergo-companion"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="dphov/omarchy-moergo-companion"
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

# Committed SHA-256 digests for release tarballs.
#
# SECURITY: The expected tarball digest lives in this repo snapshot, not on the release page.
# An attacker who replaces the GitHub release asset cannot change the value checked here.
#
# Each digest must be committed at the exact source SHA that the release is built from, so
# the release tag points to a commit that already contains its own expected digest. This binds
# the downloaded tarball to the reviewed repository snapshot; the installer fails closed
# before extraction on any mismatch.
#
# GitHub build provenance may be verified independently with:
#   gh attestation verify --repo dphov/omarchy-moergo-companion \
#     --signer-workflow dphov/omarchy-moergo-companion/.github/workflows/release.yml \
#     --predicate-type https://slsa.dev/provenance/v1 \
#     omarchy-moergo-companion-binaries-<tag>.tar.gz
#
# Procedure for adding a new digest (do not edit by hand):
#   1. Make sure CHANGELOG.md has a section for the new version.
#   2. Run `just prepare-release vX.Y.Z` (or trigger `.github/workflows/prepare-release.yml`
#      with the version). This opens a pull request containing the canonical tarball digest
#      computed by CI and a SOURCE_DATE_EPOCH timestamp.
#   3. Review and merge the pull request. The digest is now bound to the repository snapshot.
#   4. Run `just release vX.Y.Z` to push the tag. CI will verify the published tarball digest
#      matches the value committed in the merged PR.
#
# The CI release job does NOT update this table; it only verifies the artifact matches the
# value that was already committed before the tag.
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
  ["v1.2.1"]="205aba1e0f8add6b7168371379e02f182f89a326793c8254cd6734d345c16ee2"
  ["v1.2.2"]="cc25ee649aafa2f54a13abb72b6958f75e4094592ae45da27705839a773b5c09"
  ["v1.2.3"]="92162fa9301b00621157cace2493554f3e0488dc1c25de4da84700c45f309658"
  ["v1.2.4"]="adc11348a802bf4a30d03a46bf072570bc1ac8b689b7ab00af94f4326b0819cd"
  ["v1.2.5"]="adc11348a802bf4a30d03a46bf072570bc1ac8b689b7ab00af94f4326b0819cd"
)

# Trusted release workflow that signs the build provenance attestation.
RELEASE_WORKFLOW="${REPO}/.github/workflows/release.yml"

# Transfer safety limits when downloading release assets.
CURL_MAX_TIME=120
CURL_CONNECT_TIMEOUT=15
CURL_MAX_DOWNLOAD_SIZE="5M"

# Prevent concurrent bootstrap runs from multiple Quickshell service instances.
# The lock lives outside the Omarchy plugin directory so it does not trigger an
# inotify-based shell reload loop.
LOCK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/moergo-companion"
mkdir -p "$LOCK_DIR"
LOCK_FILE="$LOCK_DIR/.install.lock"
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "Another install is already running; waiting..."
  flock 200
fi

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

  # Verify signed build provenance when the GitHub CLI is available and this is
  # not an automatic startup-only run. The committed digest is the primary binding;
  # attestation is a useful secondary layer for explicit installs.
  if [[ "$ensure_only" != true ]] && command -v gh >/dev/null 2>&1; then
    if ! gh attestation verify \
      --repo "$REPO" \
      --signer-workflow "$RELEASE_WORKFLOW" \
      --predicate-type https://slsa.dev/provenance/v1 \
      "$BIN_DIR/${tarball}"; then
      echo "Error: build provenance verification failed for ${tag}." >&2
      rm -f "$BIN_DIR/${tarball}"
      return 1
    fi
    echo "Build provenance verified: repo=${REPO}, workflow=${RELEASE_WORKFLOW}."
  fi

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
    sha256sum omarchy-moergo-keymap-parser moergo-watcher moergo-companion-settings glove80-status >SHA256SUMS
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
fi

echo "Installation complete."
echo "To activate, restart the Omarchy shell:"
echo "  omarchy-restart-shell"
