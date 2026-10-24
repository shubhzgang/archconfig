import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets

// A small rounded color square for the wallpaper picker: one color, or two split diagonally (the
// second in the bottom-right half), or a tiny image. The selected one has a ring around it.
Item {
    id: root
    required property var theme
    property var colors: []          // one or two colors
    property string image: ""        // instead of the colors
    property bool selected: false
    signal clicked()

    width: 26; height: 26
    readonly property real radius: Math.min(width, height) * 0.27

    Rectangle {   // the ring, just outside the square
        anchors { fill: parent; margins: -4 }
        radius: root.radius + 4
        color: "transparent"
        border.width: 2
        border.color: root.theme.ink
        opacity: root.selected ? 1 : hover.hovered ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.colors.length ? root.colors[0] : root.theme.card
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)   // so black and white squares still show their edge
        Shape {
            anchors.fill: parent
            visible: root.colors.length > 1
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: root.colors.length > 1 ? root.colors[1] : "transparent"
                PathSvg { path: `M ${root.width} 0 L ${root.width} ${root.height} L 0 ${root.height} Z` }
            }
        }
        Image {
            anchors.fill: parent
            visible: root.image !== ""
            source: root.image ? "file://" + root.image : ""
            sourceSize: Qt.size(root.width * 2, root.height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }
}
