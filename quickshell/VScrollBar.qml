import QtQuick
import QtQuick.Effects

// Vertical scroll bar for a list or grid (any Flickable): a thin thumb in a faint track, beside its right
// edge, shown only while there is more than fits. Drag the thumb, or click the track to jump there.
// Styled as the workspace dots (CenterSection.qml): the track flat like an empty dot, the thumb like the
// focused one, with its drop shadow and its color on hover.
Item {
    id: bar
    required property var theme
    required property Flickable view

    // the whole scrollable height, the room kept above and below the content included
    readonly property real total: view.contentHeight + view.topMargin + view.bottomMargin
    readonly property real range: Math.max(0, total - view.height)
    readonly property bool needed: range > 1

    width: 19   // as thick as a workspace dot
    visible: needed

    function scrollTo(frac) {   // 0 = top, 1 = bottom
        view.contentY = view.originY - view.topMargin + Math.max(0, Math.min(1, frac)) * range
    }

    Rectangle {   // the track
        anchors.fill: parent
        radius: width / 2
        color: bar.theme.accent3
    }
    Rectangle {   // the thumb
        id: thumb
        width: parent.width
        radius: width / 2
        height: Math.min(bar.height, Math.max(34, bar.height * bar.view.height / Math.max(1, bar.total)))
        y: bar.range > 0 ? (bar.view.contentY - bar.view.originY + bar.view.topMargin) / bar.range * (bar.height - height) : 0
        color: area.containsMouse || area.pressed ? bar.theme.accent2 : bar.theme.accent
        Behavior on color { ColorAnimation { duration: 300 } }
        RectangularShadow {
            anchors.fill: parent; z: -1
            visible: bar.needed
            radius: parent.radius; offset: Qt.vector2d(0, 2); blur: 1.4; spread: 1
            color: Qt.rgba(0, 0, 0, 0.75)
        }
    }
    MouseArea {
        id: area
        anchors { fill: parent; leftMargin: -4; rightMargin: -4 }   // a little wider than it looks
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real grab: -1   // where on the thumb it was pressed, while dragging it
        onPressed: mouse => {
            const onThumb = mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height
            grab = onThumb ? mouse.y - thumb.y : thumb.height / 2   // a click on the track centers the thumb there
            move(mouse.y)
        }
        onPositionChanged: mouse => { if (pressed) move(mouse.y) }
        onReleased: grab = -1
        function move(y) {
            const free = bar.height - thumb.height
            bar.scrollTo(free > 0 ? (y - grab) / free : 0)
        }
    }
}
