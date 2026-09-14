import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
    id: root
    
    property string keyText: ""
    property bool isActive: false
    property bool isTrans: false

    readonly property bool isEmpty: keyText === ""
    readonly property bool isLayer: !isTrans && (keyText === "Layer" || keyText === "Base" || keyText === "Lower" || keyText === "Magic" || keyText === "Test")

    width: Style.space(36)
    height: Style.space(36)
    radius: Style.space(7)

    color: isActive ? Color.accent : Style.normalFill
    border.color: {
        if (isActive) return Color.accent;
        if (isLayer) return Color.accent;
        if (isEmpty) return Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.25);
        if (isTrans) return Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.45);
        return Color.muted;
    }
    border.width: isLayer ? 1.5 : 1

    Text {
        anchors.centerIn: parent
        text: root.keyText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        fontSizeMode: Text.Fit
        minimumPixelSize: 9
        font.bold: true
        color: {
            if (root.isActive) return Color.background;
            if (root.isLayer) return Color.accent;
            if (root.isTrans) return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65);
            return Color.foreground;
        }
        wrapMode: root.keyText.indexOf("\n") !== -1 ? Text.Wrap : Text.NoWrap
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 0.90
        width: parent.width - Style.space(4)
    }
}
