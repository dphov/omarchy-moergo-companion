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
)

# Full source commit SHA each release is expected to have been built from.
# Same invariant as the digests above: committed in the reviewed tree before the tag.
declare -A RELEASE_SOURCE_SHAS=(
  ["v1.1.1"]="cd1f6444ab3163c3292b32ae6646379386a2b59e"
  ["v1.1.2"]="161abae9f82586d6b64c9a83713d7be8145e51d7"
  ["v1.1.3"]="0560d7c5325631c51bb66f04eaa79da0fc3b8609"
  ["v1.1.4"]="50601f041fbd0f7a44bcc7bff95d47b1e4b937f5"
  ["v1.1.5"]="2b792c90bed191b81404368c6ca9bf4f2a7bb3b2"
  ["v1.1.6"]="80b16c65fe4142d538f57f503c50698904f43708"
  ["v1.1.7"]="145102c9c3d186a20091dc6ec2385f27cd2f6d78"
  ["v1.1.8"]="08340186e31ef14d05c1e005dc59be13e2f69b7b"
  ["v1.1.9"]="a66895d17d168f6780ef80f5eb753a7525eacec6"
  ["v1.2.0"]="eeabd127be47becf1571b8c44d700880a3c5da78"
  ["v1.2.1"]="fb4308c71f8c47d60507963cdc23879666b3168c"
  ["v1.2.2"]="a8051ea89b95fb240b6fd683911a9e8950e2371e"
)

# Trusted release workflow that signs the build provenance attestation.
RELEASE_WORKFLOW="${REPO}/.github/workflows/release.yml"

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

  # Verify signed build provenance when the GitHub CLI is available.
  # Binds the artifact to the exact repo, the trusted release workflow, and the
  # committed source SHA. Fails closed before extraction on any mismatch.
  # The committed digest check above already pins the artifact bytes, so a
  # missing gh only removes this secondary layer.
  if command -v gh >/dev/null 2>&1; then
    local expected_source_sha="${RELEASE_SOURCE_SHAS[$tag]:-}"
    local verify_args=(
      --repo "$REPO"
      --signer-workflow "$RELEASE_WORKFLOW"
      --predicate-type https://slsa.dev/provenance/v1
    )
    if [[ -n "$expected_source_sha" ]]; then
      verify_args+=(--source-ref "refs/tags/${tag}" --source-digest "$expected_source_sha")
    fi
    if ! gh attestation verify "${verify_args[@]}" "$BIN_DIR/${tarball}"; then
      echo "Error: build provenance verification failed for ${tag}." >&2
      rm -f "$BIN_DIR/${tarball}"
      return 1
    fi
    echo "Build provenance verified: repo=${REPO}, workflow=${RELEASE_WORKFLOW}, source commit=${expected_source_sha:-unpinned}."
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
