import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
    id: root

    property real contentMargin: Style.space(8)
    property real sectionSpacing: Style.space(16)

    // Telemetry passed from MoErgoCompanion.qml
    property var device: null
    property bool isConnected: false
    property bool isCharging: false
    property var batteryLevel: null
    property bool usbLeft: false
    property bool usbRight: false
    property string keymapFile: ""
    property string keymapError: ""

    signal actionRequested(string action)
    signal keymapPathSubmitted(string path)

    function applyPickedPath(path) {
        if (!path || path === "") return;
        keymapInput.text = String(path).trim();
        root.keymapPathSubmitted(keymapInput.text);
    }

    Process {
        id: filePickerProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyPickedPath(text)
        }
    }

    Flickable {
        id: dashboardScroll
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: dashboardColumn.implicitHeight + root.contentMargin * 2

        Controls.ScrollBar.vertical: Controls.ScrollBar {
            policy: Controls.ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: dashboardColumn
            x: root.contentMargin
            y: root.contentMargin
            width: dashboardScroll.width - root.contentMargin * 2
            spacing: root.sectionSpacing

        // Section 1: Device Status
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            PanelSectionHeader {
                text: "DEVICE STATUS"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: deviceColumn.implicitHeight + Style.space(20)
                color: Style.normalFill
                radius: Style.cornerRadius
                border.color: Color.muted
                border.width: 1

                ColumnLayout {
                    id: deviceColumn
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(8)

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Device Name"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (root.device && root.device.name) ? root.device.name : "Glove80"
                            font.bold: true
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Bluetooth MAC Address"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (root.device && root.device.address) ? root.device.address : "—"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Hardware Connection"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: {
                                if (root.usbLeft && root.usbRight) return "Wired USB (Both halves connected)";
                                if (root.usbLeft) return "Left: USB (Charging) / Right: Wireless";
                                if (root.usbRight) return "Left: Wireless / Right: USB (Charging)";
                                if (root.isConnected) return "Bluetooth Low Energy (BLE)";
                                return "Offline / Disconnected";
                            }
                            font.bold: true
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: root.isConnected ? Color.accent : Color.foreground
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Bluetooth Pairing"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (root.device && root.device.paired) ? "Paired" : "Not paired"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Battery Level"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: {
                                var levels = (root.device && root.device.batteryLevels) ? root.device.batteryLevels : [];
                                if (levels.length >= 2) {
                                    return "Left: " + levels[0] + "%  |  Right: " + levels[1] + "%" + (root.isCharging ? " ⚡" : "");
                                }
                                if (root.batteryLevel !== null) {
                                    return root.isCharging ? ("⚡ " + root.batteryLevel + "% (Charging via USB)") : (root.batteryLevel + "%");
                                }
                                return "Unknown";
                            }
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: root.isCharging ? Color.accent : Color.foreground
                        }
                    }
                }
            }
        }

        // Section 2: Controls
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            PanelSectionHeader {
                text: "CONTROLS"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(10)

                Button {
                    Layout.fillWidth: true
                    text: root.isConnected ? "Disconnect BLE" : "Connect BLE"
                    selected: !root.isConnected
                    bordered: true
                    onClicked: root.actionRequested(root.isConnected ? "--disconnect" : "--connect")
                }

                Button {
                    Layout.fillWidth: true
                    text: (root.device && root.device.trusted) ? "Trusted (Auto-reconnect)" : "Trust Device"
                    selected: root.device && root.device.trusted
                    bordered: true
                    onClicked: root.actionRequested((root.device && root.device.trusted) ? "--untrust" : "--trust")
                }

                Button {
                    Layout.fillWidth: true
                    text: "Forget Device"
                    bordered: true
                    onClicked: root.actionRequested("--forget")
                }
            }
        }

        // Section 3: Links
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            PanelSectionHeader {
                text: "EXTERNAL LINKS"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(10)

                Button {
                    Layout.fillWidth: true
                    text: "Glove80 Layout Editor"
                    tooltipText: "my.glove80.com"
                    bordered: true
                    onClicked: Qt.openUrlExternally("https://my.glove80.com/")
                }

                Button {
                    Layout.fillWidth: true
                    text: "ZMK Studio"
                    tooltipText: "Live keymap editor (zmk.studio)"
                    bordered: true
                    onClicked: Qt.openUrlExternally("https://zmk.studio/")
                }

                Button {
                    Layout.fillWidth: true
                    text: "Moosytype Trainer"
                    tooltipText: "Typing practice for Glove80"
                    bordered: true
                    onClicked: Qt.openUrlExternally("https://moosylog.github.io/moosytype/")
                }
            }
        }

        // Section 4: Layout Source
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            PanelSectionHeader {
                text: "LAYOUT SOURCE"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: sourceColumn.implicitHeight + Style.space(20)
                color: Style.normalFill
                radius: Style.cornerRadius
                border.color: Color.muted
                border.width: 1

                ColumnLayout {
                    id: sourceColumn
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Text {
                        text: "Path to keymap file (.keymap or .json)"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        color: Color.foreground
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(8)

                        Controls.TextField {
                            id: keymapInput
                            Layout.fillWidth: true
                            text: root.keymapFile
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.foreground
                            background: Rectangle {
                                color: Color.background
                                radius: Style.cornerRadius
                                border.color: Color.foreground
                                border.width: 1
                            }
                        }

                        Button {
                            text: "Cancel"
                            bordered: true
                            onClicked: keymapInput.text = root.keymapFile
                        }

                        Button {
                            text: "Select..."
                            bordered: true
                            onClicked: {
                                filePickerProc.command = ["zenity", "--file-selection", "--file-filter=Keymap files | *.keymap *.json"];
                                filePickerProc.running = true;
                            }
                        }

                        Button {
                            text: "Apply"
                            bordered: true
                            onClicked: {
                                root.keymapError = "";
                                root.keymapPathSubmitted(keymapInput.text);
                            }
                        }
                    }

                    Text {
                        text: "Supports ZMK .keymap files and Glove80 layout editor .json exports. The watcher will restart automatically."
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Color.foreground
                        opacity: 0.85
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.keymapError
                        visible: root.keymapError !== ""
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: Color.accent
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
    }
}
