import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
Item {
    id: root

    property var keys: []

    // Canonical Glove80 physical layout constants (in abstract units).
    readonly property real naturalUnitSize: Style.space(42)
    readonly property real keySizeRatio: 36 / 42
    readonly property real matrixWidthUnits: 19.6
    readonly property real matrixHeightUnits: 8.72

    // Tooltip layout constants
    readonly property real tooltipMaxWidth: Style.space(380)
    readonly property real tooltipHorizontalPadding: Style.space(28)
    readonly property real tooltipVerticalPadding: Style.space(22)
    readonly property real tooltipContentMargin: Style.space(24)
    readonly property real tooltipEdgeMargin: Style.space(12)
    readonly property real tooltipGap: Style.space(14)
    readonly property real tooltipFlipThreshold: Style.space(20)
    readonly property real tooltipLineHeight: 1.15

    property real unitSize: {
        if (parent && parent.width > 0 && parent.height > 0) {
            var scale = Math.min(
                parent.width / (matrixWidthUnits * naturalUnitSize),
                parent.height / (matrixHeightUnits * naturalUnitSize),
                1.0
            );
            return naturalUnitSize * scale;
        }
        return naturalUnitSize;
    }
    property real keyWidth: unitSize * keySizeRatio
    property real keyHeight: unitSize * keySizeRatio
    property string hoveredPosition: ""
    property string activeTitle: ""
    property string activeDesc: ""
    property real activeKeyX: 0
    property real activeKeyY: 0
    signal layerSwitchRequested(string layerName)

    readonly property var keyPositions: [
        // Row 0: F1-F10
        "LH C6R1", "LH C5R1", "LH C4R1", "LH C3R1", "LH C2R1",
        "RH C2R1", "RH C3R1", "RH C4R1", "RH C5R1", "RH C6R1",

        // Row 1: Number row
        "LH C6R2", "LH C5R2", "LH C4R2", "LH C3R2", "LH C2R2", "LH C1R2",
        "RH C1R2", "RH C2R2", "RH C3R2", "RH C4R2", "RH C5R2", "RH C6R2",

        // Row 2: Top alpha row
        "LH C6R3", "LH C5R3", "LH C4R3", "LH C3R3", "LH C2R3", "LH C1R3",
        "RH C1R3", "RH C2R3", "RH C3R3", "RH C4R3", "RH C5R3", "RH C6R3",

        // Row 3: Home row
        "LH C6R4", "LH C5R4", "LH C4R4", "LH C3R4", "LH C2R4", "LH C1R4",
        "RH C1R4", "RH C2R4", "RH C3R4", "RH C4R4", "RH C5R4", "RH C6R4",

        // Row 4: Lower row + Thumbs top row
        "LH C6R5", "LH C5R5", "LH C4R5", "LH C3R5", "LH C2R5", "LH C1R5",
        "LH T1", "LH T2", "LH T3",
        "RH T3", "RH T2", "RH T1",
        "RH C1R5", "RH C2R5", "RH C3R5", "RH C4R5", "RH C5R5", "RH C6R5",

        // Row 5: Bottom row + Thumbs bottom row
        "LH C6R6", "LH C5R6", "LH C4R6", "LH C3R6", "LH C2R6",
        "LH T4", "LH T5", "LH T6",
        "RH T6", "RH T5", "RH T4",
        "RH C2R6", "RH C3R6", "RH C4R6", "RH C5R6", "RH C6R6"
    ]

    implicitWidth: matrixWidthUnits * unitSize
    implicitHeight: matrixHeightUnits * unitSize

    readonly property var keyDefs: [
        { "x": 0.50, "y": 1.00, "r": 0.0 },
        { "x": 1.50, "y": 1.00, "r": 0.0 },
        { "x": 2.50, "y": 0.50, "r": 0.0 },
        { "x": 3.50, "y": 0.50, "r": 0.0 },
        { "x": 4.50, "y": 0.50, "r": 0.0 },
        { "x": 15.10, "y": 0.50, "r": 0.0 },
        { "x": 16.10, "y": 0.50, "r": 0.0 },
        { "x": 17.10, "y": 0.50, "r": 0.0 },
        { "x": 18.10, "y": 1.00, "r": 0.0 },
        { "x": 19.10, "y": 1.00, "r": 0.0 },
        { "x": 0.50, "y": 2.00, "r": 0.0 },
        { "x": 1.50, "y": 2.00, "r": 0.0 },
        { "x": 2.50, "y": 1.50, "r": 0.0 },
        { "x": 3.50, "y": 1.50, "r": 0.0 },
        { "x": 4.50, "y": 1.50, "r": 0.0 },
        { "x": 5.50, "y": 1.50, "r": 0.0 },
        { "x": 14.10, "y": 1.50, "r": 0.0 },
        { "x": 15.10, "y": 1.50, "r": 0.0 },
        { "x": 16.10, "y": 1.50, "r": 0.0 },
        { "x": 17.10, "y": 1.50, "r": 0.0 },
        { "x": 18.10, "y": 2.00, "r": 0.0 },
        { "x": 19.10, "y": 2.00, "r": 0.0 },
        { "x": 0.50, "y": 3.00, "r": 0.0 },
        { "x": 1.50, "y": 3.00, "r": 0.0 },
        { "x": 2.50, "y": 2.50, "r": 0.0 },
        { "x": 3.50, "y": 2.50, "r": 0.0 },
        { "x": 4.50, "y": 2.50, "r": 0.0 },
        { "x": 5.50, "y": 2.50, "r": 0.0 },
        { "x": 14.10, "y": 2.50, "r": 0.0 },
        { "x": 15.10, "y": 2.50, "r": 0.0 },
        { "x": 16.10, "y": 2.50, "r": 0.0 },
        { "x": 17.10, "y": 2.50, "r": 0.0 },
        { "x": 18.10, "y": 3.00, "r": 0.0 },
        { "x": 19.10, "y": 3.00, "r": 0.0 },
        { "x": 0.50, "y": 4.00, "r": 0.0 },
        { "x": 1.50, "y": 4.00, "r": 0.0 },
        { "x": 2.50, "y": 3.50, "r": 0.0 },
        { "x": 3.50, "y": 3.50, "r": 0.0 },
        { "x": 4.50, "y": 3.50, "r": 0.0 },
        { "x": 5.50, "y": 3.50, "r": 0.0 },
        { "x": 14.10, "y": 3.50, "r": 0.0 },
        { "x": 15.10, "y": 3.50, "r": 0.0 },
        { "x": 16.10, "y": 3.50, "r": 0.0 },
        { "x": 17.10, "y": 3.50, "r": 0.0 },
        { "x": 18.10, "y": 4.00, "r": 0.0 },
        { "x": 19.10, "y": 4.00, "r": 0.0 },
        { "x": 0.50, "y": 5.00, "r": 0.0 },
        { "x": 1.50, "y": 5.00, "r": 0.0 },
        { "x": 2.50, "y": 4.50, "r": 0.0 },
        { "x": 3.50, "y": 4.50, "r": 0.0 },
        { "x": 4.50, "y": 4.50, "r": 0.0 },
        { "x": 5.50, "y": 4.50, "r": 0.0 },
        { "x": 6.91, "y": 5.72, "r": 30.0 },
        { "x": 7.77, "y": 6.38, "r": 40.0 },
        { "x": 8.50, "y": 7.30, "r": 45.0 },
        { "x": 11.10, "y": 7.30, "r": -45.0 },
        { "x": 11.83, "y": 6.38, "r": -40.0 },
        { "x": 12.69, "y": 5.72, "r": -30.0 },
        { "x": 14.10, "y": 4.50, "r": 0.0 },
        { "x": 15.10, "y": 4.50, "r": 0.0 },
        { "x": 16.10, "y": 4.50, "r": 0.0 },
        { "x": 17.10, "y": 4.50, "r": 0.0 },
        { "x": 18.10, "y": 5.00, "r": 0.0 },
        { "x": 19.10, "y": 5.00, "r": 0.0 },
        { "x": 0.50, "y": 6.00, "r": 0.0 },
        { "x": 1.50, "y": 6.00, "r": 0.0 },
        { "x": 2.50, "y": 5.50, "r": 0.0 },
        { "x": 3.50, "y": 5.50, "r": 0.0 },
        { "x": 4.50, "y": 5.50, "r": 0.0 },
        { "x": 6.10, "y": 6.55, "r": 25.0 },
        { "x": 7.05, "y": 7.20, "r": 35.0 },
        { "x": 7.76, "y": 8.04, "r": 45.0 },
        { "x": 11.84, "y": 8.04, "r": -45.0 },
        { "x": 12.55, "y": 7.20, "r": -35.0 },
        { "x": 13.50, "y": 6.55, "r": -25.0 },
        { "x": 15.10, "y": 5.50, "r": 0.0 },
        { "x": 16.10, "y": 5.50, "r": 0.0 },
        { "x": 17.10, "y": 5.50, "r": 0.0 },
        { "x": 18.10, "y": 6.00, "r": 0.0 },
        { "x": 19.10, "y": 6.00, "r": 0.0 }
    ]

    Repeater {
        model: root.keyDefs
        delegate: KeyCap {
            x: modelData.x * root.unitSize - width / 2
            y: modelData.y * root.unitSize - height / 2
            rotation: modelData.r
            width: root.keyWidth
            height: root.keyHeight
            readonly property var currentKey: (root.keys && root.keys.length > index) ? root.keys[index] : null
            keyText: (typeof currentKey === "object" && currentKey !== null) ? (currentKey.text || "") : (currentKey ? String(currentKey) : "")
            keyTitle: (typeof currentKey === "object" && currentKey !== null) ? (currentKey.title || "") : ""
            keyDesc: (typeof currentKey === "object" && currentKey !== null) ? (currentKey.desc || "") : ""
            keyGlyph: (typeof currentKey === "object" && currentKey !== null) ? (currentKey.glyph || "") : ""
            keyColor: (typeof currentKey === "object" && currentKey !== null) ? (currentKey.color || "") : ""
            keyTextColor: (typeof currentKey === "object" && currentKey !== null) ? (currentKey.text_color || "") : ""
            isTrans: (typeof currentKey === "object" && currentKey !== null) ? !!currentKey.trans : false
            onIsHoveredChanged: {
                if (isHovered) {
                    root.hoveredPosition = (root.keyPositions && root.keyPositions.length > index) ? root.keyPositions[index] : "";
                    if (keyTitle !== "" || keyDesc !== "" || isLayerKey) {
                        root.activeTitle = keyTitle !== "" ? keyTitle : (isLayerKey ? ("Switch to " + targetLayer + " layer") : "");
                        root.activeDesc = keyDesc !== "" ? keyDesc : (isLayerKey ? ("Click to switch active layer tab to " + targetLayer + ".") : "");
                        root.activeKeyX = modelData.x * root.unitSize;
                        root.activeKeyY = modelData.y * root.unitSize - root.keyHeight / 2;
                    }
                } else if (root.hoveredPosition === root.keyPositions[index]) {
                    root.hoveredPosition = "";
                    root.activeTitle = "";
                    root.activeDesc = "";
                }
            }
            onLayerClicked: function(targetLayer) {
                root.layerSwitchRequested(targetLayer);
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Style.space(16)
        anchors.bottomMargin: Style.space(8)
        text: root.hoveredPosition
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        color: Color.foreground
        opacity: 0.6
        visible: root.hoveredPosition !== ""
    }

    Rectangle {
        id: infoDialog
        visible: root.activeTitle !== "" || root.activeDesc !== ""
        z: 999
        radius: Style.cornerRadius
        color: Color.background
        border.color: Color.muted
        border.width: 1

        width: Math.min(contentColumn.implicitWidth + root.tooltipHorizontalPadding, root.tooltipMaxWidth)
        height: contentColumn.implicitHeight + root.tooltipVerticalPadding

        x: Math.max(root.tooltipEdgeMargin, Math.min(root.width - width - root.tooltipEdgeMargin, root.activeKeyX - width / 2))
        y: (root.activeKeyY > height + root.tooltipFlipThreshold)
            ? (root.activeKeyY - height - root.tooltipGap)
            : (root.activeKeyY + root.keyHeight + root.tooltipGap)

        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            width: parent.width - root.tooltipContentMargin
            spacing: Style.space(4)

            Text {
                text: root.activeTitle
                font.bold: true
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: Color.accent
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            Text {
                visible: text !== ""
                text: root.activeDesc
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.foreground
                opacity: 0.88
                wrapMode: Text.Wrap
                lineHeight: 1.15
                Layout.fillWidth: true
            }
        }
    }
}
