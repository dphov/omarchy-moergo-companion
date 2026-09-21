import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var shell: null
    property var manifest: null

    readonly property int hotplugDebounceIntervalMs: 250
    readonly property int statusPollIntervalMs: 30000
    readonly property string pluginDir: {
        var resolved = String(Qt.resolvedUrl("."));
        return decodeURIComponent(resolved.replace(/^file:\/\//, ""));
    }
    readonly property string helperScript: root.pluginDir + "/bin/glove80-status"
    readonly property string watcherScript: root.pluginDir + "/bin/moergo-watcher"
    readonly property string settingsScript: root.pluginDir + "/bin/moergo-companion-settings"
    readonly property string installScript: root.pluginDir + "/install.sh"

    // Bootstrap state
    property bool binariesReady: false
    property bool bootstrapFailed: false
    property bool bootstrapInProgress: false

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

    function startServices() {
        root.binariesReady = true;
        settingsProc.command = [root.settingsScript, "--load"];
        settingsProc.running = true;
        watcherProcess.command = [root.watcherScript, root.keymapFile];
        watcherProcess.running = true;
        statusPollTimer.running = true;
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
        if (!root.binariesReady || !statusProc.running) {
            statusProc.running = true;
        }
    }

    function runAction(action) {
        if (!root.binariesReady || actionProc.running) return;
        actionProc.command = [root.helperScript, action];
        actionProc.running = true;
    }

    function saveKeymapFile(path) {
        if (!root.binariesReady || !path || path === "") return;
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
        if (!root.binariesReady) return;
        watcherProcess.running = false;
        watcherProcess.command = [root.watcherScript, root.keymapFile];
        watcherProcess.running = true;
    }

    function updateStatus(raw) {
        try {
            var data = JSON.parse(raw);
            root.isConnected = Boolean(data.connected);
            root.statusText = data.text || (root.isConnected ? "Connected" : "\uf11c Off");
            root.statusTooltip = data.tooltip || "MoErgo Glove80";
            root.battery = (data.battery !== undefined) ? data.battery : null;
            root.charging = Boolean(data.charging);
            root.usbLeft = Boolean(data.usbLeft);
            root.usbRight = Boolean(data.usbRight);
            root.deviceData = data.device || null;
        } catch (e) {
        }
    }

    Process {
        id: bootstrapProc
        command: ["bash", root.installScript, "--ensure"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                console.log("[bootstrap]", line);
            }
        }
        stderr: SplitParser {
            onRead: function(line) {
                console.error("[bootstrap]", line);
            }
        }
        onExited: function(exitCode, exitStatus) {
            root.bootstrapInProgress = false;
            if (exitCode === 0) {
                root.startServices();
            } else {
                root.bootstrapFailed = true;
                root.statusText = "No binaries";
                root.statusTooltip = "Run ~/.config/omarchy/plugins/dphov.omarchy-moergo-companion/install.sh manually";
                console.error("Bootstrap failed; install.sh exited with code", exitCode);
            }
        }
    }

    Process {
        id: statusProc
        command: [root.helperScript]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateStatus(text)
        }
    }

    Process {
        id: actionProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.refreshStatus()
        }
    }

    Process {
        id: settingsProc
        running: false
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
        running: false
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
        id: statusPollTimer
        interval: root.statusPollIntervalMs
        running: false
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: {
        if (root.binariesReady || root.bootstrapInProgress || root.bootstrapFailed) {
            return;
        }
        root.bootstrapInProgress = true;
        root.statusText = "Installing…";
        root.statusTooltip = "Downloading or building native helpers for the first time";
        bootstrapProc.running = true;
    }

    Process {
        id: watcherProcess
        running: false
        command: [root.watcherScript, root.keymapFile]
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
