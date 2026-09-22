#!/usr/bin/env bash
set -euo pipefail

# Strict qmllint invocation for this project.
# Run with unqualified-identifier checks and the import paths needed to resolve
# Quickshell, Qt, and Omarchy (qs.*) modules.

qmllint -U \
    -I /usr/lib/qt6/qml \
    -I /usr/share/omarchy/shell \
    "$(dirname "$0")/.."/*.qml \
    "$(dirname "$0")/../components"/*.qml
