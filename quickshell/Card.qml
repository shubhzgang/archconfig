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

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: root.shadowColor
        shadowBlur: 0.45
        shadowVerticalOffset: 3
    }

    Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10
    }
}
