import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
    id: root
    
    property string keyText: ""
    property bool isActive: false

    readonly property bool isEmpty: keyText === ""
    readonly property bool isTrans: keyText === "Trans"
    readonly property bool isLayer: keyText === "Layer" || keyText === "Base" || keyText === "Lower" || keyText === "Magic" || keyText === "Test"
    readonly property bool isMod: keyText === "Shift" || keyText === "Control" || keyText === "Alt" || keyText === "Gui" || keyText === "Win" || keyText === "Ctrl"
    readonly property bool isHardware: keyText.indexOf("BT") === 0 || keyText.indexOf("RGB") === 0 || keyText === "Boot" || keyText === "Reset" || keyText === "USB" || keyText === "BLE"
    readonly property bool isMedia: keyText.indexOf("Vol") === 0 || keyText.indexOf("Bri") === 0 || keyText === "Mute" || keyText === "Play" || keyText === "Prev" || keyText === "Next"

    width: Style.space(36)
    height: Style.space(36)
    radius: Style.space(7)

    opacity: isEmpty ? 0.35 : 1.0

    color: {
        if (isActive) return Color.accent;
        if (isLayer) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16);
        if (isHardware) return Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.16);
        if (isMod) return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08);
        return Style.normalFill;
    }

    border.color: {
        if (isActive) return Color.accent;
        if (isEmpty) return Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.2);
        if (isLayer) return Color.accent;
        if (isHardware) return Color.urgent;
        if (isMod) return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3);
        return Color.muted;
    }
    border.width: (isLayer || isHardware) ? 1.5 : 1
    Text {
        anchors.centerIn: parent
        text: root.keyText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        fontSizeMode: Text.Fit
        minimumPixelSize: 7
        font.bold: isLayer || isMod || isHardware || isActive
        color: {
            if (root.isActive) return Color.background;
            if (root.isLayer) return Color.accent;
            if (root.isHardware) return Color.urgent;
            if (root.isTrans) return Color.muted;
            return Color.foreground;
        }
        wrapMode: root.keyText.indexOf("\n") !== -1 ? Text.Wrap : Text.NoWrap
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 0.95
        width: parent.width - Style.space(3)
    }
}
