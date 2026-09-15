import QtQuick
import QtQuick.Layouts
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
        anchors.margins: Style.space(12)
        spacing: Style.space(12)

        RowLayout {
            id: tabRow
            Layout.fillWidth: true
            spacing: Style.space(6)

            Repeater {
                model: root.tabs
                delegate: Button {
                    text: modelData.name
                    selected: root.currentTab === index
                    bordered: true
                    onClicked: root.currentTab = index
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Color.foreground
            opacity: 0.25
        }

        Flickable {
            id: bodyFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: bodyText.implicitHeight
            clip: true

            Text {
                id: bodyText
                width: bodyFlickable.width
                text: root.bodyFor(root.tabs[root.currentTab] ? root.tabs[root.currentTab].key : "")
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: Color.foreground
                wrapMode: Text.Wrap
                lineHeight: 1.25
                textFormat: Text.PlainText
            }
        }
    }
}
