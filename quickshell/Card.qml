import QtQuick
import QtQuick.Effects

// Pale card with a soft shadow; children go in the padded column.
Rectangle {
    id: root
    required property var theme
    default property alias content: column.data
    property color shadowColor: "#55000000"

    color: theme.card
    radius: 10
    border.width: theme.glass ? 1 : 0   // glass: a thin light edge
    border.color: Qt.rgba(1, 1, 1, 0.18)
    implicitHeight: column.implicitHeight + 28

    // drawn in one pass, not from an offscreen copy of the card (which re-rendered and re-blurred
    // whenever a graph on it repainted); as faint as the card is see-through, as that copy's was.
    // (RectangularShadow matches a MultiEffect shadow at 0.45x its blur, shadowBlur x 32, plus a
    // spread of 1: the shadows elsewhere use the same conversion.)
    RectangularShadow {
        anchors.fill: parent
        z: -1
        visible: root.shadowColor.a > 0
        radius: root.radius
        offset: Qt.vector2d(0, 3)
        blur: 6.5
        spread: 1
        color: Qt.rgba(root.shadowColor.r, root.shadowColor.g, root.shadowColor.b, root.shadowColor.a * root.color.a)
    }

    Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10
    }
}
