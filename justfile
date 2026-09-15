# Justfile for Omarchy MoErgo Companion plugin

set shell := ["bash", "-c"]

# Default recipe: build, install, and restart the Omarchy shell
default: install restart

# Build the Rust keymap parser and watcher in release mode
build:
    cd keymap-parser && cargo build --release

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
