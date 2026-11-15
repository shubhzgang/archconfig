import QtQuick
import QtQuick.Effects

// A button's raised square in the left band (the media strip's, the dock's): solid in the
// workspace dots' colors (CenterSection.qml) with a dot's shadow. Lit is the focused dot's color.
Rectangle {
    id: root
    required property var theme
    property bool lit: false

    width: 30; height: 30
    radius: 7
    color: lit ? theme.accent : theme.accent2
    Behavior on color { ColorAnimation { duration: 300 } }

    RectangularShadow {   // as a workspace dot's
        anchors.fill: parent; z: -1
        visible: root.theme.shadows
        radius: parent.radius; offset: Qt.vector2d(0, 3); blur: 2.9; spread: 1
        color: Qt.rgba(0, 0, 0, 0.65)
    }
}
