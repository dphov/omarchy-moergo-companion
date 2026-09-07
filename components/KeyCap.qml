import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
    id: root
    
    property string keyText: ""
    property bool isActive: false
    
    width: Style.space(34)
    height: Style.space(34)
    radius: Style.cornerRadius
    
    color: isActive ? Color.accent : Style.normalFill
    border.color: isActive ? Color.accent : Color.muted
    border.width: 1
    
    Text {
        anchors.centerIn: parent
        text: root.keyText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: root.isActive ? Color.background : Color.foreground
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - Style.space(4)
    }
}
