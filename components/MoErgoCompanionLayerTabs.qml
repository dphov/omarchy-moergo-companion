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
    property bool showLayoutInfo: false
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
    signal layoutInfoClicked()
    signal dashboardClicked()

    Button {
        text: "<"
        bordered: true
        enabled: listView.contentX > 0
        onClicked: listView.contentX = Math.max(0, listView.contentX - listView.width * 0.8)
    }

    ListView {
        id: listView
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(contentItem.childrenRect.height, Style.space(32))
        orientation: ListView.Horizontal
        spacing: root.tabSpacing
        model: root.layers
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.currentIndex

        delegate: Button {
            text: root.layerLabel(index, modelData.name)
            selected: !root.showDashboard && root.currentIndex === index
            onClicked: root.layerClicked(index)
        }

        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex < count) {
                positionViewAtIndex(currentIndex, ListView.Contain);
            }
        }
    }

    Button {
        text: ">"
        bordered: true
        enabled: listView.contentX < listView.contentWidth - listView.width
        onClicked: listView.contentX = Math.min(
            listView.contentWidth - listView.width,
            listView.contentX + listView.width * 0.8
        )
    }

    Button {
        text: "ℹ Info"
        selected: root.showLayoutInfo
        bordered: true
        onClicked: root.layoutInfoClicked()
    }

    Button {
        text: "Dashboard"
        selected: root.showDashboard
        bordered: true
        onClicked: root.dashboardClicked()
    }
}
