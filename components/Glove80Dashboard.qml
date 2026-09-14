import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
    id: root

    // Telemetry passed from Glove80.qml
    property var device: null
    property bool isConnected: false
    property bool isCharging: false
    property var batteryLevel: null
    property bool usbLeft: false
    property bool usbRight: false

    signal actionRequested(string action)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(16)

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
                            color: Color.muted
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
                            color: Color.muted
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
                            color: Color.muted
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
                            color: root.isConnected ? Color.accent : Color.muted
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Bluetooth Pairing"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            color: Color.muted
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
                            color: Color.muted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.batteryLevel !== null ? (root.isCharging ? ("⚡ " + root.batteryLevel + "% (Charging via USB)") : (root.batteryLevel + "%")) : "Unknown"
                            font.bold: true
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

        Item { Layout.fillHeight: true }
    }
}
