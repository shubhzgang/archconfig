import QtQuick

// Small rounded option button; the selected one is filled.
Rectangle {
    id: root
    required property var theme
    property string label
    property bool selected: false
    signal clicked()

    width: text.implicitWidth + 24
    height: 28
    radius: 8
    color: selected ? theme.ink : "transparent"
    border.width: 1
    border.color: Qt.rgba(theme.ink.r, theme.ink.g, theme.ink.b, selected ? 0 : 0.45)

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label
        color: root.selected ? root.theme.dark : root.theme.ink
        font.family: "CodeNewRoman Nerd Font Mono"
        font.pixelSize: 15
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
