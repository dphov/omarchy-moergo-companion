import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Rectangle {
    id: root

    // Keycap sizing and styling constants
    readonly property real defaultKeySize: Style.space(36)
    readonly property real keyRadius: Style.space(7)
    readonly property real cornerGlyphSize: Style.space(10)
    readonly property real cornerGlyphTopMargin: Style.space(2.5)
    readonly property real cornerGlyphLeftMargin: Style.space(3)
    readonly property real textSideMargin: Style.space(2)
    readonly property real transparentHatchOpacity: 0.4
    readonly property real translucentOpacity: 0.75

    // Diagonal hatch line anchor ratios (start and end points as fractions of key size)
    readonly property real hatchStart1: 0.35
    readonly property real hatchStart2: 0.75
    readonly property real hatchEnd1: 0.25
    readonly property real hatchEnd2: 0.65

    // Stroke alignment offset for crisp 1px borders drawn inside the rectangle.
    readonly property real hairlineOffset: 0.5
    readonly property int dashPatternOn: 5
    readonly property int dashPatternOff: 4

    // Standalone glyph (used when no key text is shown)
    readonly property real standaloneGlyphMaxSize: Style.space(16)
    readonly property real standaloneGlyphMaxRatio: 0.48

    // ITU-R BT.601 luma coefficients for sRGB → luminance
    readonly property real lumaRed: 0.299
    readonly property real lumaGreen: 0.587
    readonly property real lumaBlue: 0.114
    readonly property real lightColorThreshold: 0.55

    readonly property color tealLabel: "#4a9e9e"

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
        return (c.r * lumaRed + c.g * lumaGreen + c.b * lumaBlue) > lightColorThreshold;
    }

    readonly property color resolvedForegroundColor: {
        if (root.isActive) return Color.background;
        if (root.keyTextColor !== "") return root.keyTextColor;
        if (root.keyColor !== "") return root.isLightKeyColor ? tealLabel : "#ffffff";
        return tealLabel;
    }
    readonly property bool isHovered: mouse.containsMouse
    signal layerClicked(string targetLayer)

    width: defaultKeySize
    height: defaultKeySize
    radius: keyRadius

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
            dashPattern: [root.dashPatternOn, root.dashPatternOff]
            fillColor: "transparent"

            startX: root.radius
            startY: root.hairlineOffset
            PathLine { x: root.width - root.radius; y: root.hairlineOffset }
            PathArc { x: root.width - root.hairlineOffset; y: root.radius; radiusX: root.radius - root.hairlineOffset; radiusY: root.radius - root.hairlineOffset }
            PathLine { x: root.width - root.hairlineOffset; y: root.height - root.radius }
            PathArc { x: root.width - root.radius; y: root.height - root.hairlineOffset; radiusX: root.radius - root.hairlineOffset; radiusY: root.radius - root.hairlineOffset }
            PathLine { x: root.radius; y: root.height - root.hairlineOffset }
            PathArc { x: root.hairlineOffset; y: root.height - root.radius; radiusX: root.radius - root.hairlineOffset; radiusY: root.radius - root.hairlineOffset }
            PathLine { x: root.hairlineOffset; y: root.radius }
            PathArc { x: root.radius; y: root.hairlineOffset; radiusX: root.radius - root.hairlineOffset; radiusY: root.radius - root.hairlineOffset }
        }
    }

    // Diagonal transparency hatch
    Shape {
        anchors.fill: parent
        visible: root.isTrans && !root.isActive
        layer.enabled: true
        opacity: root.transparentHatchOpacity

        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"

            startX: 0
            startY: parent.height * root.hatchStart1
            PathLine { x: parent.width * root.hatchStart1; y: 0 }
        }
        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"

            startX: 0
            startY: parent.height * root.hatchStart2
            PathLine { x: parent.width * root.hatchStart2; y: 0 }
        }
        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"

            startX: parent.width * root.hatchEnd1
            startY: parent.height
            PathLine { x: parent.width; y: parent.height * root.hatchEnd1 }
        }
        ShapePath {
            strokeColor: Color.muted
            strokeWidth: 1
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"

            startX: parent.width * root.hatchEnd2
            startY: parent.height
            PathLine { x: parent.width; y: parent.height * root.hatchEnd2 }
        }
    }

    // 1. Behavior icon: pinned to upper-left corner (MoErgo canonical layout)
    Item {
        id: cornerGlyph
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.cornerGlyphTopMargin
        anchors.leftMargin: root.cornerGlyphLeftMargin
        width: root.cornerGlyphSize
        height: width
        opacity: root.isTrans ? root.translucentOpacity : 1.0
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
            color: root.resolvedForegroundColor
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
        minimumPixelSize: 6
        font.bold: true
        color: root.resolvedForegroundColor
        wrapMode: root.keyText.indexOf("\n") !== -1 ? Text.Wrap : Text.NoWrap
        maximumLineCount: root.keyText.indexOf("\n") !== -1 ? 2 : 1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        lineHeight: 0.95
        width: parent.width - root.textSideMargin * 2
        opacity: root.isTrans ? root.translucentOpacity : 1.0
        visible: root.keyText !== ""
    }

    // 3. Standalone Glyph (when keyText is empty)
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width * root.standaloneGlyphMaxRatio, root.standaloneGlyphMaxSize)
        height: width
        opacity: root.isTrans ? root.translucentOpacity : 1.0
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
            color: root.resolvedForegroundColor
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
