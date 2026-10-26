import QtQuick

// Icon button in the frame's left band; slots count up from the bottom (slot 0 is the first one above
// the theme button, which sits above the power button). A negative slot is the power button, at the bottom. It sits in the frame, where no windows are, so it can always take the mouse.
Item {
    id: root
    required property var theme
    required property int glyph         // Nerd Font code point
    required property int slot
    property bool active: false         // the panel it opens is open
    property string label: ""           // shown instead of the glyph (the screenshot countdown)
    property bool recording: false      // a blinking red dot instead (a screen recording is running)
    signal clicked()
    readonly property int band: 48      // the frame's left band (Frame.qml)
    readonly property int size: 44      // the icon's hit area, centered in the band

    anchors { left: parent.left; bottom: parent.bottom; bottomMargin: slot < 0 ? 18 : 18 + size + 16 + (slot + 1) * (size + 4) }
    width: band
    height: size

    Text {
        anchors.centerIn: parent
        visible: !root.recording
        text: root.label || String.fromCodePoint(root.glyph)
        color: area.containsMouse || root.active ? root.theme.hover : root.theme.ink
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 26
    }
    Rectangle {   // on and off rather than fading, so the shell redraws twice a second, not every frame
        id: dot
        anchors.centerIn: parent
        visible: root.recording
        width: 20; height: 20; radius: 10
        color: "#ff3b30"
        Timer {
            interval: 500
            repeat: true
            running: root.recording
            onRunningChanged: dot.opacity = 1
            onTriggered: dot.opacity = dot.opacity === 1 ? 0.25 : 1
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
