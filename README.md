# Omarchy Moergo Companion (`dphov.omarchy-moergo-companion`)

MoErgo Glove80 visualizer and hardware status plugin for [Omarchy shell](https://github.com/omarchy).

## Features

- **Live hardware monitor**: Real-time USB connection detection for both halves (`16c0:27db` Left, `16c0:27d9` Right) + Bluetooth battery percentage via UPower/BlueZ.
- **Instant hotplug reactivity**: Monitors USB events via `udevadm monitor -s usb` with debouncing for immediate connection state updates on plug/unplug.
- **Unified bar widget**: Displays charging icon and battery level (`⚡ 96%` when wired, `96%` on battery, `Disconnected` when offline). Detailed per-half status available on hover tooltip.
- **Physical Glove80 matrix visualizer**: Authentic curved column-stagger and thumb cluster geometry.
- **Layer fall-through resolution**: Transparent (`&trans`) keys automatically resolve through the layer stack down to Base layer keys, showing exact names rather than placeholder labels.
- **Transparent key styling**: Unassigned/trans keys render with transparent fill and elegant dashed borders, while native layer keys render with solid fill and borders.
- **Interactive layer jumping**: Hovering any layer switch key (`Base`, `Lower`, `Magic`, `Test`, `Layer`) shows a tooltip and clicking jumps directly to that layer.
- **Rich keycap tooltips**: Hovering any key displays a styled floating card with its full action Title and Description (e.g. Output Selection USB, RGB controls, Bluetooth profile switching).
- **Built-in Glove80 Dashboard**: Integrated hardware control center:
  - Live device telemetry: Device Name, Bluetooth MAC address, connection transport (USB/BLE), pairing state, battery level with charging status.
  - Controls: Connect / Disconnect BLE, Trust / Untrust device (auto-reconnect), Forget device.
  - Quick Links: Glove80 Layout Editor (`my.glove80.com`), ZMK Studio (`zmk.studio`), and Moosytype trainer.
  - Editable layout source: change the ZMK keymap file path directly from the dashboard; persisted to `settings.json`.
  - Low-battery desktop notifications at $\le 20\%$ and $\le 10\%$ with hysteresis.
- **Keyboard navigation**:
  - `1` .. `4`: Jump directly to layers (Base, Lower, Magic, Test).
  - `d` (or `c`): Toggle Dashboard view.
  - `Tab` / `Shift+Tab`: Cycle forward/backward through layers.
  - `Left` / `Right` (or `h` / `l`): Navigate layer tabs.
  - `Esc`: Dismiss the panel.
## Architecture

```
├── manifest.json                   # Omarchy bar-widget plugin registration
├── MoErgoCompanion.qml             # Unified Panel: bar button + KeyboardPanel popup
├── components/
│   ├── Glove80Dashboard.qml        # Hardware control center and device status
│   ├── Glove80Matrix.qml           # Physical key matrix positioning and geometry
│   ├── KeyCap.qml                  # Keycap rendering, borders, tooltips, interaction
│   └── MoErgoCompanionLayerTabs.qml # Dynamic paginated layer selector
├── keymap_parser/                  # Decoupled Python ZMK keymap parser
│   ├── __init__.py
│   ├── __main__.py                 # CLI entry point
│   ├── behaviors.py                # ZMK behavior arity lookup
│   ├── descriptions.py             # Tooltip title/description tables
│   ├── layers.py                   # Layer name extraction/humanization
│   ├── legends.py                  # Key legend mapping tables
│   ├── models.py                   # Key/Layer dataclasses
│   ├── parser.py                   # Keymap parsing orchestration
│   ├── reader.py                   # File I/O and comment stripping
│   ├── tokenizer.py                # Bindings tokenization
│   └── transparency.py             # &trans fall-through resolution
├── bin/
│   ├── moergo-companion-settings   # Plugin settings read/write helper with validation
│   ├── glove80-status              # Python hardware monitor (USB sysfs + BlueZ/UPower)
│   └── moergo-watcher              # Polls keymap/JSON file and streams layout JSON to QML
├── parse_keymap.py                 # Thin CLI wrapper for the Python parser
└── install.sh                      # Installs plugin
```

> Note: the previous `watcher.sh` was replaced by `bin/moergo-watcher` to avoid inotifywait fragility. The C parser was replaced by the decoupled Python `keymap_parser` package.

## Dependencies

- Omarchy shell with bar-widget support
- `python3` with standard library (used by the keymap parser and `bin/glove80-status`)
- `inotifywait` from `inotify-tools` (keymap file watcher)
- `upower`, `bluez` / `bluetoothctl`, `udevadm` (hardware status and battery monitoring)
- A local Glove80 ZMK keymap at `~/.dotfiles/zmk/config/glove80.keymap` (or edit `Glove80.qml` to point elsewhere)

## Installation

### From the Omarchy marketplace

```bash
omarchy plugin add https://github.com/dphov/omarchy-moergo-companion.git --enable
omarchy-restart-shell
```

### From source

```bash
./install.sh
omarchy-restart-shell
```

The Python parser is invoked automatically by `watcher.sh`; no separate build step is required.

## Removal

```bash
omarchy plugin disable dphov.omarchy-moergo-companion
omarchy plugin remove dphov.omarchy-moergo-companion
omarchy-restart-shell
```

Or, if installed manually, delete `~/.config/omarchy/plugins/dphov.omarchy-moergo-companion/` and restart the shell.
