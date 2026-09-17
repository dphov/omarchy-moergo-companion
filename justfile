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

# Preview the next release changelog without committing, tagging, or pushing
release-bump-dry bump='patch': test lint
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
        *) echo "Usage: just release-bump-dry [patch|minor|major]"; exit 1 ;;
    esac
    version="v${major}.${minor}.${patchnum}"
    date=$(date +%Y-%m-%d)

    if git rev-parse "$latest" >/dev/null 2>&1; then
        log=$(git log "$latest"..HEAD --pretty=format:'%s' --reverse | grep -Ev '^chore\(ci\): update release binaries|skip ci')
    else
        log=$(git log --pretty=format:'%s' --reverse | grep -Ev '^chore\(ci\): update release binaries|skip ci')
    fi
    if [ -z "$log" ]; then
        log="No changes since $latest."
    fi

    added=$(echo "$log" | grep -E '^feat(\(.+\))?:' | sed 's/^/- /' || true)
    changed=$(echo "$log" | grep -E '^chore(\(.+\))?:|^refactor(\(.+\))?:|^perf(\(.+\))?:|^style(\(.+\))?:|^build(\(.+\))?:|^ci(\(.+\))?:' | sed 's/^/- /' || true)
    fixed=$(echo "$log" | grep -E '^fix(\(.+\))?:|^security(\(.+\))?:' | sed 's/^/- /' || true)
    docs=$(echo "$log" | grep -E '^docs(\(.+\))?:' | sed 's/^/- /' || true)
    other=$(echo "$log" | grep -Ev '^(feat|chore|refactor|perf|style|build|ci|fix|security|docs)(\(.+\))?:' | sed 's/^/- /' || true)

    echo "Next version: $version"
    echo "Date: $date"
    echo ""
    echo "## [${version#v}] - $date"
    echo ""
    if [ -n "$added" ]; then
        echo "### Added"
        echo ""
        echo "$added"
        echo ""
    fi
    if [ -n "$changed" ]; then
        echo "### Changed"
        echo ""
        echo "$changed"
        echo ""
    fi
    if [ -n "$fixed" ]; then
        echo "### Fixed"
        echo ""
        echo "$fixed"
        echo ""
    fi
    if [ -n "$docs" ]; then
        echo "### Documentation"
        echo ""
        echo "$docs"
        echo ""
    fi
    if [ -n "$other" ]; then
        echo "### Other"
        echo ""
        echo "$other"
        echo ""
    fi

# Simulate the GitHub Actions release packaging step locally (no tag, no push)
dry-run-release: build
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

# Compute and perform a semantic-version release (patch|minor|major)
release-bump bump='patch': test lint
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "$(git status --porcelain)" ]; then
        echo "Error: Working directory has uncommitted changes. Commit or stash them before releasing."
        exit 1
    fi
    latest=$(git tag --list 'v*' --sort=-v:refname | head -n1)
    latest=${latest:-v0.0.0}
    current=${latest#v}
    IFS='.' read -r major minor patchnum <<< "$current"
    case "{{bump}}" in
        major) major=$((major + 1)); minor=0; patchnum=0 ;;
        minor) minor=$((minor + 1)); patchnum=0 ;;
        patch) patchnum=$((patchnum + 1)) ;;
        *) echo "Usage: just release-bump [patch|minor|major]"; exit 1 ;;
    esac
    version="v${major}.${minor}.${patchnum}"
    date=$(date +%Y-%m-%d)

    # Generate changelog section from commits since the last tag
    if git rev-parse "$latest" >/dev/null 2>&1; then
        log=$(git log "$latest"..HEAD --pretty=format:'%s' --reverse | grep -Ev '^chore\(ci\): update release binaries|skip ci')
    else
        log=$(git log --pretty=format:'%s' --reverse | grep -Ev '^chore\(ci\): update release binaries|skip ci')
    fi
    if [ -z "$log" ]; then
        log="No changes since $latest."
    fi

    # Categorize commits by conventional prefix
    added=$(echo "$log" | grep -E '^feat(\(.+\))?:' | sed 's/^/- /' || true)
    changed=$(echo "$log" | grep -E '^chore(\(.+\))?:|^refactor(\(.+\))?:|^perf(\(.+\))?:|^style(\(.+\))?:|^build(\(.+\))?:|^ci(\(.+\))?:' | sed 's/^/- /' || true)
    fixed=$(echo "$log" | grep -E '^fix(\(.+\))?:|^security(\(.+\))?:' | sed 's/^/- /' || true)
    docs=$(echo "$log" | grep -E '^docs(\(.+\))?:' | sed 's/^/- /' || true)
    other=$(echo "$log" | grep -Ev '^(feat|chore|refactor|perf|style|build|ci|fix|security|docs)(\(.+\))?:' | sed 's/^/- /' || true)

    # Prepend new section to CHANGELOG.md
    tmp=$(mktemp)
    {
        echo "# Changelog"
        echo ""
        echo "All notable changes to this project will be documented in this file."
        echo ""
        echo "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),"
        echo "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)."
        echo ""
        echo "## [${version#v}] - $date"
        echo ""
        if [ -n "$added" ]; then
            echo "### Added"
            echo ""
            echo "$added"
            echo ""
        fi
        if [ -n "$changed" ]; then
            echo "### Changed"
            echo ""
            echo "$changed"
            echo ""
        fi
        if [ -n "$fixed" ]; then
            echo "### Fixed"
            echo ""
            echo "$fixed"
            echo ""
        fi
        if [ -n "$docs" ]; then
            echo "### Documentation"
            echo ""
            echo "$docs"
            echo ""
        fi
        if [ -n "$other" ]; then
            echo "### Other"
            echo ""
            echo "$other"
            echo ""
        fi
    } > "$tmp"
    awk 'NR==1{found=0} /^## \[/{if(!found){found=1; next}} found' CHANGELOG.md >> "$tmp"
    mv "$tmp" CHANGELOG.md

    git add CHANGELOG.md
    git commit -m "chore(release): update changelog for $version"
    git push origin HEAD
    git tag "$version"
    git push origin "$version"
    echo "Tagged $version, updated CHANGELOG.md, and pushed. GitHub Actions release workflow is running."

# Create a version tag and push to trigger GitHub Actions automated release
release version: test lint
    @if [ -n "$(git status --porcelain)" ]; then \
        echo "Error: Working directory has uncommitted changes. Commit or stash them before releasing."; \
        exit 1; \
    fi
    git push origin HEAD
    git tag {{version}}
    git push origin {{version}}
    @echo "Tagged {{version}} and pushed. GitHub Actions release workflow is running."
