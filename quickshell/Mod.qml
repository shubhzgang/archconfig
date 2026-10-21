import QtQuick

// One bar module: a glyph/text with waybar's 5px side padding that turns the hover color.
Item {
    id: root
    required property var theme
    property string text
    property alias hovered: area.containsMouse
    property alias font: label.font
    signal clicked(var mouse)

    implicitWidth: label.implicitWidth + 10
    implicitHeight: 39
    height: implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.hovered ? root.theme.hover : root.theme.ink
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 15
        Behavior on color { ColorAnimation { duration: 300 } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse)
    }
}
