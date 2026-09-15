import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "./components" as Components

Panel {
    id: root
    moduleName: "dphov.omarchy-moergo-companion"
    ipcTarget: "dphov.omarchy-moergo-companion"

    visible: root.statusText !== ""
    implicitWidth: visible ? button.implicitWidth : 0
    implicitHeight: visible ? button.implicitHeight : 0

    // State
    property var parsedLayout: null
    property int currentLayerIndex: 0
    property string keymapFile: Quickshell.env("HOME") + "/.dotfiles/zmk/config/glove80.keymap"
    property string jsonFile: "/tmp/glove80_layout.json"
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
    property bool showDashboard: false
    property bool showLayoutInfo: false
    readonly property string helperScript: {
        var resolved = String(Qt.resolvedUrl("bin/glove80-status"))
        return decodeURIComponent(resolved.replace(/^file:\/\//, ""))
    }
    readonly property string watcherScript: {
        var resolved = String(Qt.resolvedUrl("bin/moergo-watcher"))
        return decodeURIComponent(resolved.replace(/^file:\/\//, ""))
    }
    onParsedLayoutChanged: {
        root.currentLayerIndex = 0;
    }
    readonly property string settingsScript: {
        var resolved = String(Qt.resolvedUrl("bin/moergo-companion-settings"))
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
            root.statusText = data.text || (root.isConnected ? "Connected" : " Off");
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

    function runDashboardAction(act) {
        actionProc.command = [root.helperScript, act];
        actionProc.running = true;
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

    function saveKeymapFile(path) {
        if (!path || path === "") return;
        saveSettingsProc.command = [root.settingsScript, "--set", "keymapFile", path];
        saveSettingsProc.running = true;
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

    // Real-time Bluetooth connection & property change monitor via gdbus
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
        interval: 250
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

    Component.onCompleted: {
        settingsProc.command = [root.settingsScript, "--load"];
        settingsProc.running = true;
    }

    // Background watcher process: parses keymap and streams JSON back
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
                if (t === "d" || t === "D" || t === "c" || t === "C") {
                    root.showDashboard = !root.showDashboard;
                    return;
                }
                var num = parseInt(t, 10);
                if (!isNaN(num) && num >= 0 && root.parsedLayout && root.parsedLayout.layers) {
                    var target = num;
                    if (target < root.parsedLayout.layers.length) {
                        root.showDashboard = false;
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
                        text: root.parsedLayout && root.parsedLayout.title ? root.parsedLayout.title : "Glove80 Layout"
                        font.bold: true
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        color: Color.foreground
                    }
                    Text {
                        text: "Source: " + root.keymapFile
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: Style.space(360)
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Style.space(4)
                        visible: (!!root.parsedLayout && !!root.parsedLayout.language)
                            || (!!(root.parsedLayout && root.parsedLayout.tags) && root.parsedLayout.tags.length > 0)

                        Rectangle {
                            visible: !!(root.parsedLayout && root.parsedLayout.language)
                            color: "transparent"
                            radius: Style.cornerRadius
                            border.color: Color.muted
                            border.width: 1
                            implicitWidth: langText.implicitWidth + Style.space(10)
                            implicitHeight: langText.implicitHeight + Style.space(4)

                            Text {
                                id: langText
                                anchors.centerIn: parent
                                text: "🌐 " + (root.parsedLayout ? (root.parsedLayout.language || "") : "")
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                color: Color.foreground
                            }
                        }

                        Repeater {
                            model: root.parsedLayout ? (root.parsedLayout.tags || []) : []
                            delegate: Rectangle {
                                color: tagMouse.containsMouse ? Qt.lighter(Color.accent, 1.2) : Color.accent
                                radius: Style.cornerRadius
                                implicitWidth: tagText.implicitWidth + Style.space(10)
                                implicitHeight: tagText.implicitHeight + Style.space(4)

                                Text {
                                    id: tagText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: Color.background
                                }

                                MouseArea {
                                    id: tagMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: Qt.openUrlExternally("https://my.moergo.com/glove80/#/search?tags=" + encodeURIComponent(modelData))
                                }

                                Rectangle {
                                    visible: tagMouse.containsMouse
                                    color: Color.background
                                    border.color: Color.muted
                                    border.width: 1
                                    radius: Style.cornerRadius
                                    implicitWidth: tagTooltipText.implicitWidth + Style.space(12)
                                    implicitHeight: tagTooltipText.implicitHeight + Style.space(8)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: Style.space(4)
                                    z: 100

                                    Text {
                                        id: tagTooltipText
                                        anchors.centerIn: parent
                                        text: "Search online layouts for tag: " + modelData
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: Color.foreground
                                    }
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.statusTooltip
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.foreground
                opacity: 0.35
            }

            RowLayout {
                spacing: Style.space(8)
                Text {
                    text: "Layers"
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    opacity: 0.7
                }
                Text {
                    text: root.parsedLayout && root.parsedLayout.layers && root.parsedLayout.layers[root.currentLayerIndex]
                        ? root.parsedLayout.layers[root.currentLayerIndex].name
                        : ""
                    visible: text !== ""
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Controls.TextField {
                    id: layerSearchField
                    placeholderText: "Search layers..."
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.foreground
                    implicitWidth: Style.space(120)
                    background: Rectangle {
                        color: Color.background
                        radius: Style.cornerRadius
                        border.color: layerSearchField.activeFocus ? Color.accent : Color.muted
                        border.width: 1
                    }
                    onTextChanged: {
                        if (!root.parsedLayout || !root.parsedLayout.layers) return;
                        var query = text.toLowerCase().trim();
                        if (query === "") return;
                        for (var i = 0; i < root.parsedLayout.layers.length; i++) {
                            if (root.parsedLayout.layers[i].name.toLowerCase().indexOf(query) !== -1) {
                                root.showDashboard = false;
                                root.showLayoutInfo = false;
                                root.currentLayerIndex = i;
                                return;
                            }
                        }
                    }
                }

                Button {
                    text: "✕"
                    tooltipText: "Clear search"
                    bordered: true
                    visible: layerSearchField.text !== ""
                    onClicked: layerSearchField.text = ""
                }
            }

            // Layer Tabs
            Components.MoErgoCompanionLayerTabs {
                id: layerTabs
                Layout.fillWidth: true
                layers: root.parsedLayout ? root.parsedLayout.layers : []
                currentIndex: root.currentLayerIndex
                showDashboard: root.showDashboard
                showLayoutInfo: root.showLayoutInfo
                onLayerClicked: function(idx) {
                    root.showDashboard = false;
                    root.showLayoutInfo = false;
                    root.currentLayerIndex = idx;
                }
                onLayoutInfoClicked: {
                    root.showLayoutInfo = !root.showLayoutInfo;
                    if (root.showLayoutInfo) root.showDashboard = false;
                }
                onDashboardClicked: {
                    root.showDashboard = !root.showDashboard;
                    if (root.showDashboard) root.showLayoutInfo = false;
                }
            }

            // Visualizer Canvas
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Style.space(12)

                Components.Glove80Matrix {
                    id: matrix
                    anchors.centerIn: parent
                    visible: !root.showDashboard && !root.showLayoutInfo && root.parsedLayout && root.parsedLayout.layers && root.parsedLayout.layers.length > 0
                    keys: (root.parsedLayout && root.parsedLayout.layers && root.parsedLayout.layers[root.currentLayerIndex]) ? root.parsedLayout.layers[root.currentLayerIndex].keys : []
                    onLayerSwitchRequested: function(targetName) {
                        if (!targetName || !root.parsedLayout || !root.parsedLayout.layers) return;
                        var target = String(targetName).toLowerCase().trim();
                        for (var i = 0; i < root.parsedLayout.layers.length; i++) {
                            if (root.parsedLayout.layers[i].name.toLowerCase().trim() === target) {
                                root.showDashboard = false;
                                root.showLayoutInfo = false;
                                root.currentLayerIndex = i;
                                break;
                            }
                        }
                    }
                }

                Components.MoErgoCompanionLayoutInfo {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    visible: root.showLayoutInfo && root.parsedLayout
                    layout: root.parsedLayout
                }

                Components.MoErgoCompanionDashboard {
                    anchors.fill: parent
                    visible: root.showDashboard
                    device: root.deviceData
                    isConnected: root.isConnected
                    isCharging: root.charging
                    batteryLevel: root.battery
                    usbLeft: root.usbLeft
                    usbRight: root.usbRight
                    keymapFile: root.keymapFile
                    keymapError: root.lastKeymapError
                    onActionRequested: function(act) {
                        root.runDashboardAction(act);
                    }
                    onKeymapPathSubmitted: function(path) {
                        root.saveKeymapFile(path);
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.showDashboard && (!root.parsedLayout || !root.parsedLayout.layers || root.parsedLayout.layers.length === 0)
                    text: "No valid keymap layers found."
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }
            }
        }
    }
}
}
