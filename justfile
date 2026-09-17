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
# Run all Rust parser tests
test:
    cd keymap-parser && cargo test

# Lint all QML files
lint:
    qmllint *.qml components/*.qml

# Install the plugin to ~/.config/omarchy/plugins/
install: build
    ./install.sh

# Restart the Omarchy shell to reload the plugin
restart:
    omarchy-restart-shell

# Build, install, and restart (full reload)
reload: install restart

# Clean Rust build artifacts
clean:
    cd keymap-parser && cargo clean

# Watch for changes and reload (requires cargo-watch and just)
dev:
    cd keymap-parser && cargo watch -s 'just reload'

# Create a version tag and push to trigger GitHub Actions automated release
release version: test lint
    @if [ -n "$$(git status --porcelain)" ]; then \
        echo "Error: Working directory has uncommitted changes. Commit or stash them before releasing."; \
        exit 1; \
    fi
    git push origin HEAD
    git tag {{version}}
    git push origin {{version}}
    @echo "Tagged {{version}} and pushed. GitHub Actions release workflow is running."
