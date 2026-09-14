import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "./components" as Components

Panel {
    id: root
    moduleName: "dphov.moergomarchy"
    ipcTarget: "dphov.moergomarchy"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    // State
    property var parsedLayout: null
    property int currentLayerIndex: 0
    property string dataSource: "~/.dotfiles/zmk"
    property string keymapFile: Quickshell.env("HOME") + "/.dotfiles/zmk/config/glove80.keymap"
    property string jsonFile: "/tmp/glove80_layout.json"

    // Hardware battery & connection state
    property string statusText: "Loading…"
    property string statusTooltip: "MoErgo Glove80"
    property bool isConnected: false
    property bool charging: false
    property var battery: null
    property bool usbLeft: false
    property bool usbRight: false

    readonly property string helperScript: {
        var resolved = String(Qt.resolvedUrl("bin/glove80-status"))
        return decodeURIComponent(resolved.replace(/^file:\/\//, ""))
    }
    readonly property string watcherScript: {
        var resolved = String(Qt.resolvedUrl("watcher.sh"))
        return decodeURIComponent(resolved.replace(/^file:\/\//, ""))
    }

    function refreshStatus() {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function updateStatus(raw) {
        try {
            var data = JSON.parse(raw);
            root.isConnected = !!data.connected;
            root.statusText = data.text || (root.isConnected ? "Connected" : "Disconnected");
            root.statusTooltip = data.tooltip || "MoErgo Glove80";
            root.battery = (data.battery !== undefined) ? data.battery : null;
            root.charging = !!data.charging;
            root.usbLeft = !!data.usbLeft;
            root.usbRight = !!data.usbRight;
        } catch (e) {
            console.error("Failed to parse Glove80 status:", e);
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

    // Real-time USB hotplug monitor via udevadm
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

    Timer {
        id: hotplugDebounceTimer
        interval: 600
        repeat: false
        onTriggered: root.refreshStatus()
    }

    // Periodic polling every 30 seconds
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }
    // Native Quickshell file reader and watcher
    FileView {
        id: layoutFileView
        path: root.jsonFile
        watchChanges: true
        printErrors: true
        onLoaded: {
            try {
                root.parsedLayout = JSON.parse(text());
            } catch (e) {
                console.error("Failed to parse keymap JSON:", e);
            }
        }
    }

    // Background watcher process
    Process {
        id: watcherProcess
        command: [root.watcherScript, root.keymapFile, root.jsonFile]
        running: true
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.statusText
        fontSize: Style.font.caption
        horizontalMargin: Style.space(6)
        tooltipText: root.statusTooltip + " — Click to view layout"
        onPressed: root.toggle()
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: Style.space(900)
        contentHeight: Style.space(560)
        focusTarget: keyCatcher

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent

            onCloseRequested: root.close()
            onTabRequested: function(dir) {
                if (!root.parsedLayout || !root.parsedLayout.layers) return;
                var total = root.parsedLayout.layers.length;
                if (total <= 0) return;
                root.currentLayerIndex = (root.currentLayerIndex + dir + total) % total;
            }
            onMoveRequested: function(dx, dy) {
                if (dx !== 0 && root.parsedLayout && root.parsedLayout.layers) {
                    var total = root.parsedLayout.layers.length;
                    if (total > 0) {
                        root.currentLayerIndex = (root.currentLayerIndex + dx + total) % total;
                    }
                }
            }
            onTextKey: function(t) {
                var num = parseInt(t, 10);
                if (!isNaN(num) && num >= 1 && root.parsedLayout && root.parsedLayout.layers) {
                    var target = num - 1;
                    if (target < root.parsedLayout.layers.length) {
                        root.currentLayerIndex = target;
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(16)
            spacing: Style.space(12)

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: Style.space(2)
                    Text { 
                        text: "Glove80 Layout"
                        font.bold: true
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        color: Color.foreground 
                    }
                    Text { 
                        text: "Source: " + root.keymapFile
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption 
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.statusTooltip
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.muted
                opacity: 0.3
            }

            // Layer Tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)
                Repeater {
                    model: root.parsedLayout ? root.parsedLayout.layers : []
                    delegate: Button {
                        text: modelData.name
                        selected: root.currentLayerIndex === index
                        onClicked: root.currentLayerIndex = index
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // Visualizer Canvas
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Style.normalFill
                radius: Style.cornerRadius
                border.color: Color.muted
                border.width: 1

                Components.Glove80Matrix {
                    anchors.centerIn: parent
                    visible: root.parsedLayout && root.parsedLayout.layers && root.parsedLayout.layers.length > 0
                    keys: (root.parsedLayout && root.parsedLayout.layers && root.parsedLayout.layers[root.currentLayerIndex]) ? root.parsedLayout.layers[root.currentLayerIndex].keys : []
                    onLayerSwitchRequested: function(targetName) {
                        if (!root.parsedLayout || !root.parsedLayout.layers) return;
                        for (var i = 0; i < root.parsedLayout.layers.length; i++) {
                            if (root.parsedLayout.layers[i].name.toLowerCase() === targetName.toLowerCase()) {
                                root.currentLayerIndex = i;
                                break;
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.parsedLayout || !root.parsedLayout.layers || root.parsedLayout.layers.length === 0
                    text: "Downloading & Parsing Keymap..."
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }
            }
        }
    }
}
}
