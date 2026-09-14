import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Rectangle {
    id: root
    
    property string keyText: ""
    property bool isActive: false
    property bool isTrans: false
    readonly property bool isLayerKey: keyText === "Layer" || keyText === "Base" || keyText === "Lower" || keyText === "Magic" || keyText === "Test"
    readonly property string targetLayer: {
        if (keyText === "Layer") return "Lower";
        if (isLayerKey) return keyText;
        return "";
    }

    signal clicked()

    width: Style.space(36)
    height: Style.space(36)
    radius: Style.space(7)

    color: isActive ? Color.accent : (isTrans ? "transparent" : Style.normalFill)
    border.color: (mouse.containsMouse && isLayerKey) ? Color.accent : (isActive ? Color.accent : Color.muted)
    border.width: isTrans && !(mouse.containsMouse && isLayerKey) ? 0 : 1

    Shape {
        anchors.fill: parent
        visible: root.isTrans && !root.isActive
        layer.enabled: true

        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [5, 4]
            fillColor: "transparent"

            startX: root.radius
            startY: 0.5
            PathLine { x: root.width - root.radius; y: 0.5 }
            PathArc { x: root.width - 0.5; y: root.radius; radiusX: root.radius - 0.5; radiusY: root.radius - 0.5 }
            PathLine { x: root.width - 0.5; y: root.height - root.radius }
            PathArc { x: root.width - root.radius; y: root.height - 0.5; radiusX: root.radius - 0.5; radiusY: root.radius - 0.5 }
            PathLine { x: root.radius; y: root.height - 0.5 }
            PathArc { x: 0.5; y: root.height - root.radius; radiusX: root.radius - 0.5; radiusY: root.radius - 0.5 }
            PathLine { x: 0.5; y: root.radius }
            PathArc { x: root.radius; y: 0.5; radiusX: root.radius - 0.5; radiusY: root.radius - 0.5 }
        }
    }

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

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.isLayerKey ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    PanelToolTip {
        visible: mouse.containsMouse && root.isLayerKey
        text: "Switch to " + root.targetLayer + " layer"
        fontFamily: Style.font.family
    }
}
