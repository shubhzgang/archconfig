import QtQuick
import Quickshell.Widgets

// The track playing, in the frame's left band: a small album art with the title and artist above it,
// written bottom to top. A line longer than its space scrolls (pausing at its start each time round).
// Click to open the media panel.
Item {
    id: strip
    required property var theme
    required property var media
    property bool active: false        // the media panel is open
    property bool animate: true        // false while it can't be seen
    signal clicked()

    readonly property int band: 48     // the frame's left band (Frame.qml)
    readonly property real textLen: 200
    width: band
    height: art.height + 10 + textLen

    readonly property color tint: area.containsMouse || active ? theme.hover : theme.ink

    ClippingRectangle {
        id: art
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: 30; height: 30
        radius: 7
        color: Qt.rgba(strip.theme.ink.r, strip.theme.ink.g, strip.theme.ink.b, 0.15)
        opacity: strip.media.playing ? 1 : 0.6
        Text {   // no art: a note
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: String.fromCodePoint(0xF075A)
            color: strip.tint
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 18
        }
        Image {
            id: cover
            anchors.fill: parent
            source: strip.media.art
            sourceSize: Qt.size(60, 60)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Item {   // the line, laid out left to right and turned to read bottom to top
        id: window
        width: strip.textLen
        height: strip.band
        x: (strip.width - width) / 2
        y: (strip.textLen - height) / 2
        rotation: -90
        clip: true
        opacity: strip.media.playing ? 1 : 0.6

        readonly property string line: strip.media.title + (strip.media.artist ? "  ·  " + strip.media.artist : "")
        readonly property bool scrolls: first.implicitWidth > width
        readonly property real gap: 48
        property real offset: 0
        onLineChanged: { offset = 0; if (scroll.running) scroll.restart() }

        Text {
            id: first
            anchors.verticalCenter: parent.verticalCenter
            x: -window.offset
            text: window.line
            color: strip.tint
            font.family: "CodeNewRoman Nerd Font Mono"
            font.pixelSize: 15
        }
        Text {   // the line again, following it round
            anchors.verticalCenter: parent.verticalCenter
            visible: window.scrolls
            x: first.x + first.implicitWidth + window.gap
            text: window.line
            color: strip.tint
            font: first.font
        }
        SequentialAnimation {
            id: scroll
            running: window.scrolls && strip.animate
            loops: Animation.Infinite
            PauseAnimation { duration: 1500 }
            NumberAnimation {
                target: window; property: "offset"
                from: 0; to: first.implicitWidth + window.gap
                duration: (first.implicitWidth + window.gap) / 40 * 1000   // 40px a second
            }
            onRunningChanged: if (!running) window.offset = 0
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: strip.clicked()
    }
}
