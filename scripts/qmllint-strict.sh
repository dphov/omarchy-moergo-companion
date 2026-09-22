#!/usr/bin/env bash
set -euo pipefail

# Strict qmllint invocation for this project.
# Enables unqualified-identifier checks and resolves Qt/Quickshell types via
# their installed .qmltypes files. Omarchy's qs.Ui/qs.Commons modules ship
# only .qml files, so their types may not resolve until .qmltypes are generated
# for them. In that case the strict run produces import-resolution warnings but
# still surfaces real Qt/Quickshell issues.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Collect all installed .qmltypes files under the Qt import tree.
QMLTYPES_FLAGS=()
while IFS= read -r qmltypes; do
  QMLTYPES_FLAGS+=("-i" "$qmltypes")
done < <(find /usr/lib/qt6/qml -name '*.qmltypes' -print)

qmllint -U \
    "${QMLTYPES_FLAGS[@]}" \
    -I /usr/share/omarchy/shell \
    "$ROOT"/*.qml \
    "$ROOT/components"/*.qml
