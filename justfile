# Justfile for Omarchy MoErgo Companion plugin

set shell := ["bash", "-c"]

# Default recipe: build, install, and restart the Omarchy shell
default: install restart

# Build the Rust keymap parser and helpers in release mode from locked source
build:
    cd keymap-parser && cargo build --release --locked
    mkdir -p bin
    cp keymap-parser/target/release/omarchy-moergo-keymap-parser bin/
    cp keymap-parser/target/release/moergo-watcher bin/
    cp keymap-parser/target/release/moergo-companion-settings bin/
    cp keymap-parser/target/release/glove80-status bin/
    cd bin && sha256sum glove80-status moergo-companion-settings moergo-watcher omarchy-moergo-keymap-parser > SHA256SUMS

# Generate and display SHA-256 checksums for binaries in bin/
sha:
    @mkdir -p bin
    cd bin && sha256sum glove80-status moergo-companion-settings moergo-watcher omarchy-moergo-keymap-parser > SHA256SUMS
    @cat bin/SHA256SUMS

# Verify binary integrity against bin/SHA256SUMS
verify-sha:
    cd bin && sha256sum -c SHA256SUMS

# Run all Rust parser tests (locked to committed Cargo.lock)
test:
    cd keymap-parser && cargo test --locked

# Lint all QML files
lint:
    qmllint *.qml components/*.qml

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
    echo "All release binaries are compiled directly from the reviewed, locked Rust source (\`keymap-parser/Cargo.lock\`) on GitHub Actions and distributed as release assets."
    echo "To verify that your downloaded binaries match the attested build:"
    echo ""
    echo '```bash'
    echo "sha256sum -c SHA256SUMS"
    echo "gh attestation verify --owner dphov --predicate-type https://slsa.dev/provenance/v1 omarchy-moergo-keymap-parser"
    echo '```'
    echo ""
    echo "### Checksums"
    echo ""
    echo "SHA-256 values will be inserted here by the release workflow."

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

# Simulate the GitHub Actions release packaging step locally (no tag, no push)
release-dry: build
    @mkdir -p release-assets
    cp bin/omarchy-moergo-keymap-parser release-assets/
    cp bin/moergo-watcher release-assets/
    cp bin/moergo-companion-settings release-assets/
    cp bin/glove80-status release-assets/
    cd release-assets \
        && tar -czvf "omarchy-moergo-companion-binaries-dryrun.tar.gz" \
            omarchy-moergo-keymap-parser moergo-watcher moergo-companion-settings glove80-status \
        && sha256sum omarchy-moergo-keymap-parser moergo-watcher moergo-companion-settings glove80-status omarchy-moergo-companion-binaries-dryrun.tar.gz > SHA256SUMS \
        && sha256sum -c SHA256SUMS
    @echo "Dry-run release assets staged in release-assets/:"
    @cat release-assets/SHA256SUMS
