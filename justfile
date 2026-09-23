# Justfile for Omarchy MoErgo Companion plugin

set shell := ["bash", "-c"]

# Default recipe: build, install, and restart the Omarchy shell
default: install restart

# Rust target for release binaries: static musl for reproducibility across distros
export TARGET := "x86_64-unknown-linux-musl"

# Reproducibility flags used for release binaries (must match .github/workflows/release.yml)
export CARGO_INCREMENTAL := "0"
export RUSTFLAGS := "--remap-path-prefix=$PWD=/build --remap-path-prefix=$HOME=/home -C link-arg=-Wl,--build-id=none"

# Build the Rust keymap parser and helpers in release mode from locked source
build:
    cd keymap-parser && rustup target add {{TARGET}}
    cd keymap-parser && cargo build --release --locked --target {{TARGET}}
    mkdir -p bin
    cp keymap-parser/target/{{TARGET}}/release/omarchy-moergo-keymap-parser bin/
    cp keymap-parser/target/{{TARGET}}/release/moergo-watcher bin/
    cp keymap-parser/target/{{TARGET}}/release/moergo-companion-settings bin/
    cp keymap-parser/target/{{TARGET}}/release/glove80-status bin/
    cd bin && \
      for bin in glove80-status moergo-companion-settings moergo-watcher omarchy-moergo-keymap-parser; do printf '%s\0' "$bin"; done | sort -z | xargs -0 -r sha256sum > SHA256SUMS

# Generate and display SHA-256 checksums for binaries in bin/
sha:
    @mkdir -p bin
    cd bin && \
      for bin in glove80-status moergo-companion-settings moergo-watcher omarchy-moergo-keymap-parser; do printf '%s\0' "$bin"; done | sort -z | xargs -0 -r sha256sum > SHA256SUMS
    @cat bin/SHA256SUMS

# Verify binary integrity against bin/SHA256SUMS
verify-sha:
    cd bin && sha256sum -c SHA256SUMS

# Run all Rust parser tests (locked to committed Cargo.lock)
test:
    cd keymap-parser && cargo test --locked

# Lint all QML files with unqualified-identifier checks and project import paths
lint:
    ./scripts/qmllint-strict.sh

# Run all code-quality checks (format, clippy, tests, qmllint)
check:
    cd keymap-parser && cargo fmt --check
    cd keymap-parser && cargo clippy --locked --all-targets -- -D warnings
    cd keymap-parser && cargo test --locked
    qmllint *.qml components/*.qml

# Run checks and commit with the provided message
commit message: check
    git add -A
    git commit -m "{{message}}"

# Install the plugin to ~/.config/omarchy/plugins/ (uses prebuilt bin/ if present)
install:
    ./install.sh

# Restart the Omarchy shell to reload the plugin
restart:
    omarchy-restart-shell

# Build, install, and restart (full reload)
reload: build install restart

# Clean Rust build artifacts
clean:
    cd keymap-parser && cargo clean

# Watch for changes and reload (requires cargo-watch and just)
dev:
    cargo watch --watch-when-idle -w keymap-parser/src -w components -s 'just reload'

# Draft a CHANGELOG.md section from commits since the last tag (no side effects)
changelog-draft bump='patch':
    #!/usr/bin/env bash
    set -euo pipefail
    latest=$(git tag --list 'v*' --sort=-v:refname | head -n1)
    latest=${latest:-v0.0.0}
    current=${latest#v}
    IFS='.' read -r major minor patchnum <<< "$current"
    case "{{bump}}" in
        major) major=$((major + 1)); minor=0; patchnum=0 ;;
        minor) minor=$((minor + 1)); patchnum=0 ;;
        patch) patchnum=$((patchnum + 1)) ;;
        *) echo "Usage: just changelog-draft [patch|minor|major]"; exit 1 ;;
    esac
    version="v${major}.${minor}.${patchnum}"
    date=$(date +%Y-%m-%d)

    if git rev-parse "$latest" >/dev/null 2>&1; then
        log=$(git log "$latest"..HEAD --pretty=format:'%s' --reverse | grep -Ev '^chore\(ci\): update release binaries|skip ci')
    else
        log=$(git log --pretty=format:'%s' --reverse | grep -Ev '^chore\(ci\): update release binaries|skip ci')
    fi

    section="## [${version#v}] - $date"
    added=$(echo "$log" | grep -E '^feat(\(.+\))?:' | sed 's/^/- /' || true)
    changed=$(echo "$log" | grep -E '^chore(\(.+\))?:|^refactor(\(.+\))?:|^perf(\(.+\))?:|^style(\(.+\))?:|^build(\(.+\))?:|^ci(\(.+\))?:' | sed 's/^/- /' || true)
    fixed=$(echo "$log" | grep -E '^fix(\(.+\))?:|^security(\(.+\))?:' | sed 's/^/- /' || true)
    docs=$(echo "$log" | grep -E '^docs(\(.+\))?:' | sed 's/^/- /' || true)
    other=$(echo "$log" | grep -Ev '^(feat|chore|refactor|perf|style|build|ci|fix|security|docs)(\(.+\))?:' | sed 's/^/- /' || true)

    [ -n "$added" ] && section+=$(printf '\n\n### Added\n\n%s' "$added")
    [ -n "$changed" ] && section+=$(printf '\n\n### Changed\n\n%s' "$changed")
    [ -n "$fixed" ] && section+=$(printf '\n\n### Fixed\n\n%s' "$fixed")
    [ -n "$docs" ] && section+=$(printf '\n\n### Documentation\n\n%s' "$docs")
    [ -n "$other" ] && section+=$(printf '\n\n### Other\n\n%s' "$other")

    echo "$section"
    echo ""
    echo "Paste the section above into CHANGELOG.md, then run: just release ${version}"

# Preview the GitHub release body for an explicit version without side effects
release-preview version:
    #!/usr/bin/env bash
    set -euo pipefail
    bare="{{version}}"
    bare="${bare#v}"
    if [ ! -f CHANGELOG.md ]; then
        echo "CHANGELOG.md not found."
        exit 1
    fi
    section=$(awk '/^## \['"$bare"'\]/{flag=1; next} /^## \[/{flag=0} flag' CHANGELOG.md)
    if [ -z "$section" ]; then
        echo "No CHANGELOG.md section found for {{version}}."
        exit 1
    fi
    echo "$section"
    echo ""
    echo "---"
    echo ""
    echo "### Verifying Binary Provenance"
    echo ""
    echo "All release binaries are compiled directly from the reviewed, locked Rust source (\`keymap-parser/Cargo.lock\`) on GitHub Actions and packaged as a single tarball with an internal \`SHA256SUMS\` manifest."
    echo "To download and verify the tarball:"
    echo ""
    echo '```bash'
    echo "tag={{version}}"
    echo "curl -fsSL -O \"https://github.com/dphov/omarchy-moergo-companion/releases/download/${tag}/omarchy-moergo-companion-binaries-${tag}.tar.gz\""
    echo "# Compare the tarball digest to the value committed in install.sh"
    echo "sha256sum omarchy-moergo-companion-binaries-${tag}.tar.gz"
    echo "mkdir -p bin && tar -xzf omarchy-moergo-companion-binaries-${tag}.tar.gz -C bin"
    echo "cd bin && sha256sum -c SHA256SUMS"
    echo '```'
    echo ""
    echo "To verify signed build provenance:"
    echo ""
    echo '```bash'
    echo "gh attestation verify --owner dphov --predicate-type https://slsa.dev/provenance/v1 omarchy-moergo-companion-binaries-{{version}}.tar.gz"
    echo '```'
    echo ""
    echo "### Checksums"
    echo ""
    echo "SHA-256 values for the binaries and the tarball will be inserted here by the release workflow."

# Open an automated release preparation PR for the given version.
# The PR contains SOURCE_DATE_EPOCH and the tarball digest for the release.
prepare-release version:
    #!/usr/bin/env bash
    set -euo pipefail
    tag="{{version}}"
    if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: version must match vX.Y.Z (e.g., v1.2.3)." >&2
        exit 1
    fi
    echo "Triggering prepare-release workflow for $tag..."
    gh workflow run prepare-release.yml -f version="$tag"

# Create a version tag and push to trigger GitHub Actions automated release
release version: check
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "$(git status --porcelain)" ]; then
        echo "Error: Working directory has uncommitted changes. Commit or stash them before releasing."
        exit 1
    fi
    bare="{{version}}"
    bare="${bare#v}"
    if [ ! -f CHANGELOG.md ]; then
        echo "Error: CHANGELOG.md is missing."
        exit 1
    fi
    if ! awk '/^## \['"$bare"'\]/{found=1; exit} END{exit !found}' CHANGELOG.md; then
        echo "Error: No CHANGELOG.md section found for {{version}}."
        exit 1
    fi

    # The tarball digest and SOURCE_DATE_EPOCH must already be committed at this SHA.
    tag="{{version}}"
    if ! grep -qF "[\"$tag\"]=" install.sh; then
        echo "Error: no committed tarball digest in install.sh for $tag." >&2
        echo "Run 'just prepare-release $tag' to open a PR with the digest," >&2
        echo "merge the PR, then run 'just release $tag' to push the tag." >&2
        exit 1
    fi
    if [ ! -f SOURCE_DATE_EPOCH ]; then
        echo "Error: SOURCE_DATE_EPOCH file is missing. Create it (e.g. date +%s > SOURCE_DATE_EPOCH)" >&2
        echo "and commit it together with the release digest in install.sh." >&2
        exit 1
    fi

    # Sync manifest.json version with the release tag
    sed -i -E 's/("version"[[:space:]]*:[[:space:]]*")[^"]+(".*)/\1'"$bare"'\2/' manifest.json
    if [ -n "$(git status --porcelain manifest.json)" ]; then
        git add manifest.json
        git commit -m "chore(release): bump manifest.json to {{version}}"
        git push origin HEAD
    fi

    git tag {{version}}
    git push origin {{version}}
    echo "Tagged {{version}} and pushed. GitHub Actions release workflow is running."

# Simulate the GitHub Actions release packaging step locally (no tag, no push).
# Note: the packaging is deterministic, but the Rust binaries may differ from the
# CI build because of distro/toolchain differences, so use the CI dry-run
# workflow (release-dry.yml) for the canonical release digest.
release-dry: build
    @mkdir -p release-assets
    cp bin/omarchy-moergo-keymap-parser release-assets/
    cp bin/moergo-watcher release-assets/
    cp bin/moergo-companion-settings release-assets/
    cp bin/glove80-status release-assets/
    cp bin/SHA256SUMS release-assets/
    # Deterministic tarball: sorted entries, fixed mtime/owner, no gzip timestamp.
    @if [ ! -f SOURCE_DATE_EPOCH ]; then \
      echo "Error: SOURCE_DATE_EPOCH file is missing. Create it and commit it with the release digest." >&2; \
      exit 1; \
    fi
    bash -c 'set -euo pipefail; \
      export SOURCE_DATE_EPOCH="$(cat SOURCE_DATE_EPOCH)"; \
      GZIP=-n tar \
        --sort=name \
        --mtime="@${SOURCE_DATE_EPOCH}" \
        --owner=0 --group=0 --numeric-owner \
        --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
        -czf omarchy-moergo-companion-binaries-dryrun.tar.gz -C release-assets .; \
      mv omarchy-moergo-companion-binaries-dryrun.tar.gz release-assets/; \
      cd release-assets; \
      sha256sum omarchy-moergo-companion-binaries-dryrun.tar.gz > SHA256SUMS; \
      sha256sum -c SHA256SUMS'
    @echo "Dry-run release assets staged in release-assets/:"
    @cat release-assets/SHA256SUMS

