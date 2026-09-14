# Moergomarchy (`dphov.moergomarchy`)

MoErgo Glove80 visualizer and hardware status plugin for [Omarchy shell](https://github.com/omarchy).

## Features

- **Live hardware monitor**: Real-time USB connection detection for both halves (`16c0:27db` Left, `16c0:27d9` Right) + Bluetooth battery percentage via UPower/BlueZ.
- **Instant hotplug reactivity**: Monitors USB events via `udevadm monitor -s usb` with debouncing for immediate connection state updates on plug/unplug.
- **Unified bar widget**: Displays charging icon and battery level (`⚡ 96%` when wired, `96%` on battery, `Disconnected` when offline). Detailed per-half status available on hover tooltip.
- **Physical Glove80 matrix visualizer**: Authentic curved column-stagger and thumb cluster geometry.
- **Layer fall-through resolution**: Transparent (`&trans`) keys automatically resolve through the layer stack down to Base layer keys, showing exact names rather than placeholder labels.
- **Transparent key styling**: Unassigned/trans keys render with transparent fill and elegant dashed borders, while native layer keys render with solid fill and borders.
- **Interactive layer jumping**: Hovering any layer switch key (`Base`, `Lower`, `Magic`, `Test`, `Layer`) shows a tooltip and clicking jumps directly to that layer.
- **Keyboard navigation**:
  - `1` .. `4`: Jump directly to layers (Base, Lower, Magic, Test).
  - `Tab` / `Shift+Tab`: Cycle forward/backward through layers.
  - `Left` / `Right` (or `h` / `l`): Navigate layer tabs.
  - `Esc`: Dismiss the panel.

## Architecture

```
├── manifest.json            # Omarchy bar-widget plugin registration
├── Glove80.qml              # Unified Panel: bar button + KeyboardPanel popup
├── components/
│   ├── Glove80Matrix.qml    # Physical key matrix positioning and geometry
│   └── KeyCap.qml           # Individual keycap rendering, borders, and interaction
├── bin/
│   └── glove80-status       # Python hardware monitor (USB sysfs + BlueZ/UPower)
├── parser.c                 # Native C ZMK keymap parser with layer resolution
├── watcher.sh               # Inotify file watcher re-parsing on keymap edit
└── install.sh               # Builds C parser and installs plugin
```

## Installation

```bash
./install.sh
omarchy-restart-shell
```
