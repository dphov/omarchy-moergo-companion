import QtQuick
import qs.Commons
import qs.Ui
Rectangle {
    id: root
    
    property string keyText: ""
    property bool isActive: false
    property bool isTrans: false

    width: Style.space(36)
    height: Style.space(36)
    radius: Style.space(7)

    color: isActive ? Color.accent : (isTrans ? "transparent" : Style.normalFill)
    border.color: isActive ? Color.accent : Color.muted
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: root.keyText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        fontSizeMode: Text.Fit
        minimumPixelSize: 9
        font.bold: true
        color: root.isActive ? Color.background : Color.foreground
        wrapMode: root.keyText.indexOf("\n") !== -1 ? Text.Wrap : Text.NoWrap
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.0
        width: parent.width - Style.space(2)
    }
}
