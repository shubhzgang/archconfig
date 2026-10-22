import QtQuick

// Title + current value row above a Graph.
Item {
    id: root
    required property var theme
    property string title
    property string value
    property alias series: graph.series
    property alias ymax: graph.ymax
    property alias points: graph.points
    property alias interval: graph.interval
    property alias maxLabel: graph.maxLabel
    property alias mirrored: graph.mirrored
    property alias ymax2: graph.ymax2
    property alias maxLabel2: graph.maxLabel2

    implicitHeight: 164   // the stats panel shrinks it so every graph fits
    height: implicitHeight

    Text {
        id: titleText
        text: root.title
        color: root.theme.dark
        font.family: "CodeNewRoman Nerd Font Mono"
        font.pixelSize: 19
        font.bold: true
    }
    Text {
        anchors.right: parent.right
        text: root.value
        color: root.theme.dark
        font.family: "CodeNewRoman Nerd Font Mono"
        font.pixelSize: 17
    }
    Graph {
        id: graph
        gridColor: Qt.rgba(root.theme.dark.r, root.theme.dark.g, root.theme.dark.b, 0.15)
        labelColor: Qt.rgba(root.theme.dark.r, root.theme.dark.g, root.theme.dark.b, 0.5)
        anchors { top: titleText.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom }
    }
}
