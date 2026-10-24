import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets

// A small rounded color square for the wallpaper picker: one color, or several in diagonal bands from
// the top-left corner (two split it on the diagonal), or a tiny image. The selected one has a ring
// around it.
Item {
    id: root
    required property var theme
    property var colors: []          // one color or more
    property string image: ""        // instead of the colors
    property bool selected: false
    signal clicked()

    width: 32; height: 32
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
        Repeater {   // each color after the first covers the square from its band onwards
            model: root.colors.slice(1)
            delegate: Shape {
                required property string modelData
                required property int index
                // the band starts where x / width + y / height reaches k (0 at the top-left, 2 at the bottom-right)
                readonly property real k: 2 * (index + 1) / root.colors.length
                readonly property real w: root.width
                readonly property real h: root.height
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: modelData
                    PathSvg {
                        path: k <= 1 ? `M ${k * w} 0 L ${w} 0 L ${w} ${h} L 0 ${h} L 0 ${k * h} Z`
                                     : `M ${w} ${(k - 1) * h} L ${w} ${h} L ${(k - 1) * w} ${h} Z`
                    }
                }
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
