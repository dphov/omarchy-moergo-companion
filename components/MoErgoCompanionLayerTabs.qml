import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

RowLayout {
    id: root
    spacing: root.tabSpacing

    property var layers: []
    property int currentIndex: 0
    property bool showDashboard: false
    property real tabSpacing: Style.space(6)
    property string layerNamePrefix: "Layer "

    function layerLabel(index, name) {
        var rawName = String(name);
        var displayName = rawName.startsWith(root.layerNamePrefix)
            ? rawName.slice(root.layerNamePrefix.length)
            : rawName;
        return index + " " + displayName;
    }


    signal layerClicked(int index)
    signal dashboardClicked()

    Button {
        text: "<"
        bordered: true
        enabled: flickable.contentX > 0
        onClicked: flickable.contentX = Math.max(0, flickable.contentX - flickable.width * 0.8)
    }

    Flickable {
        id: flickable
        Layout.fillWidth: true
        Layout.preferredHeight: tabRow.implicitHeight
        contentWidth: tabRow.implicitWidth
        contentHeight: tabRow.implicitHeight
        flickableDirection: Flickable.HorizontalFlick
        interactive: false
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        RowLayout {
            id: tabRow
            spacing: root.tabSpacing

            Repeater {
                model: root.layers
                delegate: Button {
                    text: root.layerLabel(index, modelData.name)
                    selected: !root.showDashboard && root.currentIndex === index
                    onClicked: root.layerClicked(index)
                }
            }
        }
    }

    Button {
        text: ">"
        bordered: true
        enabled: flickable.contentX < flickable.contentWidth - flickable.width
        onClicked: flickable.contentX = Math.min(
            flickable.contentWidth - flickable.width,
            flickable.contentX + flickable.width * 0.8
        )
    }

    Button {
        text: "Dashboard"
        selected: root.showDashboard
        bordered: true
        onClicked: root.dashboardClicked()
    }
}
