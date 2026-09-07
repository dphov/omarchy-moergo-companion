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

    // Placeholder variables for UPower
    property int batteryLeft: 92
    property int batteryRight: 88
    property bool isConnected: true

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
        command: ["bash", "-c", "cd ~/.config/omarchy/plugins/dphov.moergomarchy && ./watcher.sh '" + root.keymapFile + "' '" + root.jsonFile + "'"]
        running: true
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.isConnected ? root.batteryLeft + "% | " + root.batteryRight + "%" : "Disconnected"
        fontSize: Style.font.caption
        horizontalMargin: Style.space(6)
        tooltipText: "MoErgo Glove80"
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
