import QtQuick

// Button at the bottom of the frame's left band that cycles the theme mode (dark, normal, light) of
// the shell's colors. It sits in the frame, where no windows are, so it can always take the mouse.
Item {
    id: root
    required property var theme
    readonly property int band: 48      // the frame's left band (Frame.qml)
    readonly property int size: 44      // the icon's hit area, centered in the band

    anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 18 + 48 }   // above the opacity button
    width: band
    height: size

    Text {
        anchors.centerIn: parent
        // moon, half-and-half, sun
        text: String.fromCodePoint(root.theme.mode === "dark" ? 0xF0594 : root.theme.mode === "light" ? 0xF0599 : 0xF050E)
        color: area.containsMouse ? root.theme.hover : root.theme.ink
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 26
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.theme.cycleMode()
    }
}
