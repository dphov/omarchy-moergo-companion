import QtQuick
import qs.Commons
import qs.Ui

Item {
    id: root

    property var keys: []
    property real unitSize: Style.space(42)
    property real keyWidth: Style.space(36)
    property real keyHeight: Style.space(36)
    signal layerSwitchRequested(string layerName)


    implicitWidth: 19.6 * unitSize
    implicitHeight: 8.72 * unitSize

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
            isTrans: (typeof currentKey === "object" && currentKey !== null) ? !!currentKey.trans : false
            onLayerClicked: function(targetLayer) {
                root.layerSwitchRequested(targetLayer);
            }
        }
    }
}
