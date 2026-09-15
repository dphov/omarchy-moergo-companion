import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Rectangle {
    id: root
    
    property string keyText: ""
    property string keyTitle: ""
    property string keyDesc: ""
    property string keyGlyph: ""
    property string keyColor: ""
    property string keyTextColor: ""
    property bool isActive: false
    property bool isTrans: false
    readonly property string normalizedKeyText: keyText.replace(/\s+/g, " ").trim()
    readonly property bool isLayerKey: {
        var k = normalizedKeyText.toLowerCase();
        return k === "layer" || k === "base" || k === "lower" || k === "magic" || k === "test";
    }
    readonly property string targetLayer: {
        var k = normalizedKeyText.toLowerCase();
        if (k === "layer") return "Lower";
        if (k === "base") return "Base";
        if (k === "lower") return "Lower";
        if (k === "magic") return "Magic";
        if (k === "test") return "Test";
        return "";
    }

    readonly property bool isLightKeyColor: {
        if (!keyColor || keyColor === "") return false;
        var c = Qt.color(keyColor);
        return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) > 0.55;
    }

    readonly property color tealLabel: "#4a9e9e"

    readonly property color resolvedTextColor: {
        if (root.isActive) return Color.background;
        if (root.keyTextColor !== "") return root.keyTextColor;
        if (root.keyColor !== "") return root.isLightKeyColor ? tealLabel : "#ffffff";
        return tealLabel;
    }

    readonly property color resolvedIconColor: {
        if (root.isActive) return Color.background;
        if (root.keyTextColor !== "") return root.keyTextColor;
        if (root.keyColor !== "") return root.isLightKeyColor ? tealLabel : "#ffffff";
        return tealLabel;
    }
    readonly property bool isHovered: mouse.containsMouse
    signal layerClicked(string targetLayer)

    width: Style.space(36)
    height: Style.space(36)
    radius: Style.space(7)

    color: isActive ? Color.accent : (isTrans ? "transparent" : (root.keyColor !== "" ? root.keyColor : Style.normalFill))
    border.color: (mouse.containsMouse && isLayerKey) ? Color.accent : (isActive ? Color.accent : (root.keyColor !== "" ? Qt.darker(root.keyColor, 1.25) : Color.muted))
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

    // Diagonal transparency hatch
    Shape {
        anchors.fill: parent
        visible: root.isTrans && !root.isActive
        layer.enabled: true
        opacity: 0.4

        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"

            startX: 0
            startY: root.height * 0.35
            PathLine { x: root.width * 0.35; y: 0 }
        }
        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"

            startX: 0
            startY: root.height * 0.75
            PathLine { x: root.width * 0.75; y: 0 }
        }
        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"

            startX: root.width * 0.25
            startY: root.height
            PathLine { x: root.width; y: root.height * 0.25 }
        }
        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"

            startX: root.width * 0.65
            startY: root.height
            PathLine { x: root.width; y: root.height * 0.65 }
        }
    }

    // 1. Behavior icon: pinned to upper-left corner (MoErgo canonical layout)
    Item {
        id: cornerGlyph
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Style.space(2.5)
        anchors.leftMargin: Style.space(3)
        width: Style.space(10)
        height: width
        opacity: root.isTrans ? 0.75 : 1.0
        visible: root.keyGlyph !== "" && root.keyText !== ""

        Image {
            id: cornerGlyphImg
            anchors.fill: parent
            source: root.keyGlyph !== "" ? Qt.resolvedUrl("../assets/key-glyphs/" + root.keyGlyph + ".svg") : ""
            fillMode: Image.PreserveAspectFit
            visible: root.keyGlyph === "di-linux"
        }

        ColorOverlay {
            anchors.fill: cornerGlyphImg
            source: cornerGlyphImg
            visible: root.keyGlyph !== "di-linux"
            color: root.resolvedIconColor
        }
    }

    // 2. Center Keycode / Parameter (MoErgo canonical layout)
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (root.keyGlyph !== "" && root.keyText.indexOf("\n") === -1) ? Style.space(2) : 0
        text: root.keyText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        fontSizeMode: Text.Fit
        minimumPixelSize: 9
        font.bold: true
        color: root.resolvedTextColor
        wrapMode: root.keyText.indexOf("\n") !== -1 ? Text.Wrap : Text.WordWrap
        maximumLineCount: 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        lineHeight: 1.0
        width: parent.width - Style.space(4)
        opacity: root.isTrans ? 0.75 : 1.0
        visible: root.keyText !== ""
    }

    // 3. Standalone Glyph (when keyText is empty)
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.48, Style.space(16))
        height: width
        opacity: root.isTrans ? 0.75 : 1.0
        visible: root.keyGlyph !== "" && root.keyText === ""

        Image {
            id: standaloneGlyphImg
            anchors.fill: parent
            source: root.keyGlyph !== "" ? Qt.resolvedUrl("../assets/key-glyphs/" + root.keyGlyph + ".svg") : ""
            fillMode: Image.PreserveAspectFit
            visible: root.keyGlyph === "di-linux"
        }

        ColorOverlay {
            anchors.fill: standaloneGlyphImg
            source: standaloneGlyphImg
            visible: root.keyGlyph !== "di-linux"
            color: root.resolvedIconColor
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.isLayerKey ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.targetLayer !== "") {
                root.layerClicked(root.targetLayer);
            }
        }
    }

}
