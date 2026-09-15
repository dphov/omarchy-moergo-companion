import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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

    Row {
        anchors.centerIn: parent
        spacing: Style.space(2)
        visible: root.keyGlyph !== "" && root.keyText !== ""

        Image {
            id: rowGlyphImg
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(root.width * 0.28, Style.space(11))
            height: width
            source: root.keyGlyph !== "" ? Qt.resolvedUrl("../assets/key-glyphs/" + root.keyGlyph + ".svg") : ""
            fillMode: Image.PreserveAspectFit
            visible: root.keyColor === ""
        }

        MultiEffect {
            anchors.fill: rowGlyphImg
            source: rowGlyphImg
            visible: root.keyColor !== ""
            colorization: 1.0
            colorizationColor: "#1a1e22"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.keyText
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            fontSizeMode: Text.Fit
            minimumPixelSize: 7
            font.bold: true
            color: root.isActive ? Color.background : (root.keyColor !== "" ? "#1a1e22" : Color.foreground)
            wrapMode: Text.NoWrap
            horizontalAlignment: Text.AlignLeft
            lineHeight: 1.0
            width: Math.min(implicitWidth, root.width - Style.space(15))
        }
    }

    Image {
        id: standaloneGlyphImg
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.48, Style.space(18))
        height: width
        source: root.keyGlyph !== "" ? Qt.resolvedUrl("../assets/key-glyphs/" + root.keyGlyph + ".svg") : ""
        visible: root.keyGlyph !== "" && root.keyText === "" && root.keyColor === ""
        fillMode: Image.PreserveAspectFit
    }

    MultiEffect {
        anchors.fill: standaloneGlyphImg
        source: standaloneGlyphImg
        visible: root.keyGlyph !== "" && root.keyText === "" && root.keyColor !== ""
        colorization: 1.0
        colorizationColor: "#1a1e22"
    }
    Text {
        anchors.centerIn: parent
        text: root.keyText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        fontSizeMode: Text.Fit
        minimumPixelSize: 9
        font.bold: true
        color: root.isActive ? Color.background : (root.keyColor !== "" ? "#1a1e22" : Color.foreground)
        wrapMode: root.keyText.indexOf("\n") !== -1 ? Text.Wrap : Text.NoWrap
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.0
        width: parent.width - Style.space(2)
        visible: root.keyGlyph === "" && root.keyText !== ""
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
