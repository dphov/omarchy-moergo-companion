import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

Rectangle {
    id: root
    color: Color.background
    radius: Style.cornerRadius
    border.color: Color.muted
    border.width: 1

    property var layout: null
    property int currentTab: 0

    // Layout constants
    readonly property real contentMargin: Style.space(12)
    readonly property real tabRowSpacing: Style.space(6)
    readonly property real bodySpacing: Style.space(8)
    readonly property real dividerHeight: 1
    readonly property real dividerOpacity: 0.25
    readonly property real codeLineHeight: 1.25
    readonly property int firstLineNumber: 1

    function copyCurrentBody() {
        var key = root.tabs[root.currentTab] ? root.tabs[root.currentTab].key : "";
        var body = root.bodyFor(key);
        if (body === "") return;
        copyProc.command = ["wl-copy", body];
        copyProc.running = true;
    }

    Process {
        id: copyProc
        command: ["wl-copy"]
    }

    readonly property var tabs: {
        var list = [];
        if (root.layout && root.layout.notes && root.layout.notes !== "") list.push({ name: "Notes", key: "notes" });
        if (root.layout && root.layout.custom_defined_behaviors && root.layout.custom_defined_behaviors !== "") list.push({ name: "Custom Defined Behaviors", key: "custom_defined_behaviors" });
        if (root.layout && root.layout.custom_devicetree && root.layout.custom_devicetree !== "") list.push({ name: "Custom Device-tree", key: "custom_devicetree" });
        if (root.layout && root.layout.config_parameters && root.layout.config_parameters !== "") list.push({ name: "Advanced Configuration", key: "config_parameters" });
        return list;
    }

    function bodyFor(key) {
        if (!root.layout) return "";
        if (key === "notes") return root.layout.notes || "";
        if (key === "custom_defined_behaviors") return root.layout.custom_defined_behaviors || "";
        if (key === "custom_devicetree") return root.layout.custom_devicetree || "";
        if (key === "config_parameters") return root.layout.config_parameters || "";
        return "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.contentMargin
        spacing: root.contentMargin

        RowLayout {
            id: tabRow
            Layout.fillWidth: true
            spacing: root.tabRowSpacing

            Repeater {
                model: root.tabs
                delegate: Button {
                    text: modelData.name
                    selected: root.currentTab === index
                    bordered: true
                    onClicked: root.currentTab = index
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Copy"
                tooltipText: "Copy this section to clipboard"
                bordered: true
                onClicked: root.copyCurrentBody()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: root.dividerHeight
            color: Color.foreground
            opacity: root.dividerOpacity
        }

        Flickable {
            id: bodyFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: bodyRow.implicitWidth
            contentHeight: bodyRow.implicitHeight
            clip: true

            Row {
                id: bodyRow
                spacing: root.bodySpacing

                Text {
                    id: lineNumberText
                    text: {
                        var body = root.bodyFor(root.tabs[root.currentTab] ? root.tabs[root.currentTab].key : "");
                        var count = body.split("\n").length;
                        var lines = [];
                        for (var i = root.firstLineNumber; i < root.firstLineNumber + count; i++) {
                            lines.push(i);
                        }
                        return lines.join("\n");
                    }
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    color: Color.muted
                    lineHeight: root.codeLineHeight
                    textFormat: Text.PlainText
                }

                Text {
                    id: bodyText
                    text: root.bodyFor(root.tabs[root.currentTab] ? root.tabs[root.currentTab].key : "")
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    color: Color.foreground
                    wrapMode: Text.NoWrap
                    lineHeight: root.codeLineHeight
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
