import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui
Rectangle {
    id: root
    
    property string keyText: ""
    property bool isActive: false
    property bool isTrans: false

    readonly property bool isEmpty: keyText === ""
    readonly property bool isLayer: keyText === "Layer" || keyText === "Base" || keyText === "Lower" || keyText === "Magic" || keyText === "Test"

    width: Style.space(36)
    height: Style.space(36)
    radius: Style.space(7)

    color: isActive ? Color.accent : Style.normalFill
    border.color: {
        if (isActive) return Color.accent;
        if (isLayer) return Color.accent;
        if (isEmpty) return Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.25);
        return Color.muted;
    }
    border.width: isTrans ? 0 : (isLayer ? 1.5 : 1)

    Shape {
        anchors.fill: parent
        visible: root.isTrans && !root.isActive
        layer.enabled: true

        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 2]
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
        color: {
            if (root.isActive) return Color.background;
            if (root.isLayer) return Color.accent;
            return Color.foreground;
        }
        wrapMode: root.keyText.indexOf("\n") !== -1 ? Text.Wrap : Text.NoWrap
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 0.90
        width: parent.width - Style.space(4)
    }
}
