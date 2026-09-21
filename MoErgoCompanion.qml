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

    readonly property var moergoService: bar && bar.shell
        ? bar.shell.serviceFor(root.moduleName) : null

    readonly property var parsedLayout: moergoService ? moergoService.parsedLayout : null
    readonly property int currentLayerIndex: moergoService ? moergoService.currentLayerIndex : 0
    readonly property string keymapFile: moergoService ? moergoService.keymapFile : ""
    readonly property string lastKeymapError: moergoService ? moergoService.lastKeymapError : ""

    readonly property string statusText: moergoService ? moergoService.statusText : "Loading…"
    readonly property string statusTooltip: moergoService ? moergoService.statusTooltip : "MoErgo Glove80"
    readonly property bool isConnected: moergoService ? moergoService.isConnected : false
    readonly property bool charging: moergoService ? moergoService.charging : false
    readonly property var battery: moergoService ? moergoService.battery : null
    readonly property bool usbLeft: moergoService ? moergoService.usbLeft : false
    readonly property bool usbRight: moergoService ? moergoService.usbRight : false
    readonly property var deviceData: moergoService ? moergoService.deviceData : null

    visible: root.statusText !== ""
    implicitWidth: visible ? button.implicitWidth : 0
    implicitHeight: visible ? button.implicitHeight : 0

    // Layout constants
    readonly property real panelContentWidth: Style.space(900)
    readonly property real panelContentHeight: Style.space(560)
    readonly property real buttonHorizontalMargin: Style.space(6)

    readonly property real panelMargin: Style.space(16)
    readonly property real panelSpacing: Style.space(12)
    readonly property real titleMaxWidth: Style.space(360)
    readonly property real layerNameMinWidth: Style.space(120)

    // Z-ordering constants
    readonly property int tooltipZ: 100

    // Opacity constants
    readonly property real separatorOpacity: 0.35
    readonly property real hintOpacity: 0.7

    // UI-only state
    property bool showDashboard: false
    property bool showLayoutInfo: false

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.statusText
        fontSize: Style.font.caption
        horizontalMargin: root.buttonHorizontalMargin
        tooltipText: root.statusTooltip + " — Click to view layout"
        onPressed: root.toggle()
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: root.panelContentWidth
        contentHeight: root.panelContentHeight
        focusTarget: keyCatcher

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent

            onCloseRequested: root.close()
            onTabRequested: function(dir) {
                if (!root.moergoService) return;
                root.moergoService.changeLayer(dir);
            }
            onMoveRequested: function(dx, dy) {
                if (!root.moergoService) return;
                if (dx !== 0) root.moergoService.changeLayer(dx);
            }
            onTextKey: function(t) {
                if (t === "d" || t === "D" || t === "c" || t === "C") {
                    root.showDashboard = !root.showDashboard;
                    return;
                }
                var num = parseInt(t, 10);
                if (!isNaN(num) && num >= 0 && root.moergoService) {
                    root.showDashboard = false;
                    root.showLayoutInfo = false;
                    root.moergoService.setLayer(num);
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.panelMargin
                spacing: root.panelSpacing

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
                            Layout.maximumWidth: root.titleMaxWidth
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Style.space(4)
                            visible: (root.parsedLayout !== null && root.parsedLayout.language !== undefined && root.parsedLayout.language !== "")
                                || ((root.parsedLayout !== null && root.parsedLayout.tags !== undefined) && root.parsedLayout.tags.length > 0)

                            Rectangle {
                                visible: root.parsedLayout !== null && root.parsedLayout.language !== undefined && root.parsedLayout.language !== ""
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
                                        z: root.tooltipZ

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
                    opacity: root.separatorOpacity
                }

                RowLayout {
                    spacing: Style.space(8)
                    Text {
                        text: "Layers"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        opacity: root.hintOpacity
                    }
                    Text {
                        id: currentLayerNameText
                        text: root.parsedLayout && root.parsedLayout.layers && root.parsedLayout.layers[root.currentLayerIndex]
                            ? root.parsedLayout.layers[root.currentLayerIndex].name
                            : ""
                        visible: text !== ""
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.showDashboard = false;
                                root.showLayoutInfo = false;
                                layerTabs.refocusCurrent();
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Controls.TextField {
                        id: layerSearchField
                        placeholderText: "Search layers..."
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Color.foreground
                        implicitWidth: root.layerNameMinWidth
                        background: Rectangle {
                            color: Color.background
                            radius: Style.cornerRadius
                            border.color: layerSearchField.activeFocus ? Color.accent : Color.muted
                            border.width: 1
                        }
                        onTextChanged: {
                            if (!root.parsedLayout || !root.parsedLayout.layers || !root.moergoService) return;
                            var query = text.toLowerCase().trim();
                            if (query === "") return;
                            for (var i = 0; i < root.parsedLayout.layers.length; i++) {
                                if (root.parsedLayout.layers[i].name.toLowerCase().indexOf(query) !== -1) {
                                    root.showDashboard = false;
                                    root.showLayoutInfo = false;
                                    root.moergoService.setLayer(i);
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
                        Layout.preferredWidth: visible ? implicitWidth : 0
                        Layout.maximumWidth: visible ? implicitWidth : 0
                        Layout.preferredHeight: layerSearchField.implicitHeight
                        Layout.maximumHeight: layerSearchField.implicitHeight
                        Layout.alignment: Qt.AlignVCenter
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
                        if (!root.moergoService) return;
                        root.showDashboard = false;
                        root.showLayoutInfo = false;
                        root.moergoService.setLayer(idx);
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

                    Components.Glove80Matrix {
                        id: matrix
                        anchors.centerIn: parent
                        visible: !root.showDashboard && !root.showLayoutInfo && root.parsedLayout && root.parsedLayout.layers && root.parsedLayout.layers.length > 0
                        keys: (root.parsedLayout && root.parsedLayout.layers && root.parsedLayout.layers[root.currentLayerIndex]) ? root.parsedLayout.layers[root.currentLayerIndex].keys : []
                        onLayerSwitchRequested: function(targetName) {
                            if (!root.moergoService) return;
                            root.showDashboard = false;
                            root.showLayoutInfo = false;
                            root.moergoService.setLayerByName(targetName);
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
                            if (root.moergoService) root.moergoService.runAction(act);
                        }
                        onKeymapPathSubmitted: function(path) {
                            if (root.moergoService) root.moergoService.saveKeymapFile(path);
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
