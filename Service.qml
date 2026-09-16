import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var shell: null
    property var manifest: null

    readonly property int hotplugDebounceIntervalMs: 250
    readonly property int statusPollIntervalMs: 30000
    readonly property string runtimeDir: {
        var xdg = Quickshell.env("XDG_RUNTIME_DIR");
        if (xdg && xdg.length > 0) {
            return xdg + "/omarchy-moergo-companion";
        }
        var user = Quickshell.env("USER") || "user";
        return "/tmp/omarchy-moergo-" + user;
    }
    readonly property string jsonFile: root.runtimeDir + "/glove80_layout.json"
    readonly property string helperScript: {
        var resolved = String(Qt.resolvedUrl("bin/glove80-status"))
        return decodeURIComponent(resolved.replace(/^file:\/\//, ""))
    }
    readonly property string watcherScript: {
        var resolved = String(Qt.resolvedUrl("bin/moergo-watcher"))
        return decodeURIComponent(resolved.replace(/^file:\/\//, ""))
    }
    readonly property string settingsScript: {
        var resolved = String(Qt.resolvedUrl("bin/moergo-companion-settings"))
        return decodeURIComponent(resolved.replace(/^file:\/\//, ""))
    }

    // Keymap/layout state
    property var parsedLayout: null
    property int currentLayerIndex: 0
    property string keymapFile: Quickshell.env("HOME") + "/.dotfiles/zmk/config/glove80.keymap"
    property string lastKeymapError: ""

    // Hardware battery & connection state
    property string statusText: "Loading…"
    property string statusTooltip: "MoErgo Glove80"
    property bool isConnected: false
    property bool charging: false
    property var battery: null
    property bool usbLeft: false
    property bool usbRight: false
    property var deviceData: null

    onParsedLayoutChanged: {
        root.currentLayerIndex = 0;
    }

    function setLayer(index) {
        if (!root.parsedLayout || !root.parsedLayout.layers) return;
        var total = root.parsedLayout.layers.length;
        if (total <= 0) return;
        if (index >= 0 && index < total) {
            root.currentLayerIndex = index;
        }
    }

    function changeLayer(delta) {
        if (!root.parsedLayout || !root.parsedLayout.layers) return;
        var total = root.parsedLayout.layers.length;
        if (total <= 0) return;
        root.currentLayerIndex = (root.currentLayerIndex + delta + total) % total;
    }

    function setLayerByName(name) {
        if (!name || !root.parsedLayout || !root.parsedLayout.layers) return;
        var target = String(name).toLowerCase().trim();
        for (var i = 0; i < root.parsedLayout.layers.length; i++) {
            if (root.parsedLayout.layers[i].name.toLowerCase().trim() === target) {
                root.currentLayerIndex = i;
                return;
            }
        }
    }

    function refreshStatus() {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function runAction(action) {
        if (actionProc.running) return;
        actionProc.command = [root.helperScript, action];
        actionProc.running = true;
    }

    function saveKeymapFile(path) {
        if (!path || path === "") return;
        saveSettingsProc.command = [root.settingsScript, "--set", "keymapFile", path];
        saveSettingsProc.running = true;
    }

    function applySettings(settings) {
        if (!settings) return;
        if (settings.success === false) {
            root.lastKeymapError = settings.error || "Invalid keymap file";
            return;
        }
        root.lastKeymapError = "";
        if (settings.keymapFile && settings.keymapFile !== "") {
            root.keymapFile = settings.keymapFile;
            root.restartWatcher();
        }
    }

    function restartWatcher() {
        watcherProcess.running = false;
        watcherProcess.command = [root.watcherScript, root.keymapFile, root.jsonFile];
        watcherProcess.running = true;
    }

    function updateStatus(raw) {
        try {
            var data = JSON.parse(raw);
            root.isConnected = !!data.connected;
            root.statusText = data.text || (root.isConnected ? "Connected" : "\uf11c Off");
            root.statusTooltip = data.tooltip || "MoErgo Glove80";
            root.battery = (data.battery !== undefined) ? data.battery : null;
            root.charging = !!data.charging;
            root.usbLeft = !!data.usbLeft;
            root.usbRight = !!data.usbRight;
            root.deviceData = data.device || null;
        } catch (e) {
        }
    }

    Process {
        id: statusProc
        command: [root.helperScript]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateStatus(text)
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.refreshStatus()
        }
    }

    Process {
        id: settingsProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.applySettings(JSON.parse(text));
                } catch (e) {
                    console.error("Failed to parse settings:", e);
                }
            }
        }
    }

    Process {
        id: saveSettingsProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.applySettings(JSON.parse(text));
                } catch (e) {
                    console.error("Failed to save settings:", e);
                }
            }
        }
    }

    Process {
        id: udevMonitor
        command: ["udevadm", "monitor", "-u", "-s", "usb"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.indexOf("add") !== -1 || line.indexOf("remove") !== -1) {
                    hotplugDebounceTimer.restart();
                }
            }
        }
    }

    Process {
        id: bluezMonitor
        command: ["gdbus", "monitor", "--system", "-d", "org.bluez"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.indexOf("PropertiesChanged") !== -1 ||
                    line.indexOf("InterfacesAdded") !== -1 ||
                    line.indexOf("InterfacesRemoved") !== -1 ||
                    line.indexOf("Connected") !== -1) {
                    hotplugDebounceTimer.restart();
                }
            }
        }
    }

    Timer {
        id: hotplugDebounceTimer
        interval: root.hotplugDebounceIntervalMs
        repeat: false
        onTriggered: root.refreshStatus()
    }

    Timer {
        interval: root.statusPollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: {
        settingsProc.command = [root.settingsScript, "--load"];
        settingsProc.running = true;
    }

    Process {
        id: watcherProcess
        command: [root.watcherScript, root.keymapFile, root.jsonFile]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                line = String(line).trim();
                if (line.indexOf("{") !== 0) return;
                try {
                    root.parsedLayout = JSON.parse(line);
                } catch (e) {
                    console.error("Failed to parse keymap JSON:", e);
                }
            }
        }
    }
}
