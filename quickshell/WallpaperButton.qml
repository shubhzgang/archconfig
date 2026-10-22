import QtQuick

// Button in the frame's left band, above the theme button, that opens the wallpaper picker.
Item {
    id: root
    required property var theme
    property bool active: false         // the picker is open
    signal clicked()
    readonly property int band: 48      // the frame's left band (Frame.qml)
    readonly property int size: 44      // the icon's hit area, centered in the band

    anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 18 + size + 4 }   // above the theme button
    width: band
    height: size

    Text {
        anchors.centerIn: parent
        text: String.fromCodePoint(0xF0E09)   // wallpaper
        color: area.containsMouse || root.active ? root.theme.hover : root.theme.ink
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 26
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
