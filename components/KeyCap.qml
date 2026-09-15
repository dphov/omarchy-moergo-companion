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

    readonly property color resolvedTextColor: {
        if (root.isActive) return Color.background;
        if (root.keyTextColor !== "") return root.keyTextColor;
        if (root.keyColor !== "") return root.isLightKeyColor ? "#1a1e22" : "#ffffff";
        return Color.foreground;
    }

    readonly property color resolvedIconColor: {
        if (root.isActive) return Color.background;
        if (root.keyTextColor !== "") return root.keyTextColor;
        if (root.keyColor !== "") return root.isLightKeyColor ? "#1a1e22" : "#ffffff";
        return "#c7cf9b";
    }

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

    // 1. Behavior icon: pinned to upper-left corner (MoErgo canonical layout)
    Item {
        id: cornerGlyph
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Style.space(2.5)
        anchors.leftMargin: Style.space(3)
        width: Style.space(10)
        height: width
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
        minimumPixelSize: 7
        font.bold: true
        color: root.resolvedTextColor
        wrapMode: root.keyText.indexOf("\n") !== -1 ? Text.Wrap : Text.WordWrap
        maximumLineCount: 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        lineHeight: 0.92
        width: parent.width - Style.space(4)
        visible: root.keyText !== ""
    }

    // 3. Standalone Glyph (when keyText is empty)
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.48, Style.space(16))
        height: width
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

    ToolTip {
        id: toolTip
        visible: mouse.containsMouse && (root.keyTitle !== "" || root.keyDesc !== "" || root.isLayerKey)
        delay: 200
        padding: Style.space(12)
        x: (root.width - implicitWidth) / 2
        y: (root.y > root.height * 2.5) ? (-implicitHeight - Style.space(10)) : (root.height + Style.space(8))
        background: Rectangle {
            color: Color.background
            border.color: Color.muted
            border.width: 1
            radius: Style.cornerRadius
        }

        contentItem: ColumnLayout {
            spacing: Style.space(6)

            Text {
                text: root.keyTitle !== "" ? root.keyTitle : (root.isLayerKey ? ("Switch to " + root.targetLayer + " layer") : root.keyText)
                font.bold: true
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: Color.accent
            }

            Text {
                visible: text !== ""
                text: root.keyDesc !== "" ? root.keyDesc : (root.isLayerKey ? ("Click to switch active layer tab to " + root.targetLayer + ".") : "")
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: Color.foreground
                wrapMode: Text.Wrap
                lineHeight: 1.15
                Layout.maximumWidth: Style.space(320)
            }
        }
    }
}
