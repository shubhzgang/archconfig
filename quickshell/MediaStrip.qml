import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The track playing, in the frame's left band: a disc, turning while it plays, with the title and
// artist above it,
// written bottom to top, under a play/pause button. A line longer than its space scrolls while the track plays (pausing at its
// start each time round). They sit on a pill colored like the workspace dots (CenterSection.qml): the
// focused dot's color while playing, a dot with windows' while paused, swapped on hover. The button is
// raised off the fainter pill (Raised.qml).
// Click to open the media panel (the button plays or pauses).
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
    height: play.height + 8 + art.height + 10 + textLen + 8   // 4px above the button and below the art, in the pill

    readonly property color tint: theme.ink

    Rectangle {   // the pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: 38; height: parent.height
        radius: 10
        readonly property bool swapped: area.containsMouse || strip.active
        readonly property color dot: strip.media.playing !== swapped ? strip.theme.accent : strip.theme.accent2
        color: Qt.rgba(dot.r, dot.g, dot.b, swapped ? 0.6 : 0.35)   // fainter than a dot: it's much bigger
        Behavior on color { ColorAnimation { duration: 300 } }

        RectangularShadow {   // as a workspace dot's
            anchors.fill: parent; z: -1
            visible: strip.theme.shadows
            radius: parent.radius; offset: Qt.vector2d(0, 3); blur: 2.9; spread: 1
            color: Qt.rgba(0, 0, 0, 0.65 * parent.color.a)   // as faint as the pill is see-through (Card.qml)
        }
    }

    Raised {   // play / pause, as in the media panel
        id: play
        anchors { top: parent.top; topMargin: 4; horizontalCenter: parent.horizontalCenter }
        z: 1   // above the strip's mouse area
        theme: strip.theme
        lit: strip.media.playing !== playArea.containsMouse
        opacity: strip.media.player?.canTogglePlaying ? 1 : 0.35
        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: strip.media.playing ? 0 : 1   // the triangle looks centred
            text: String.fromCodePoint(strip.media.playing ? 0xF03E4 : 0xF040A)
            color: strip.tint
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 18
        }
        MouseArea {
            id: playArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: strip.media.player?.canTogglePlaying ?? false
            cursorShape: Qt.PointingHandCursor
            onClicked: strip.media.player.togglePlaying()
        }
    }

    Item {   // the disc
        id: art
        anchors { bottom: parent.bottom; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
        width: 30; height: 30
        opacity: strip.media.playing ? 1 : 0.6
        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xF0025)
            color: strip.tint
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 26
        }
        Shape {   // its shine: two short arcs on opposite sides of the hole, to see it turn
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer   // smooth edges
            ShapePath {
                strokeColor: strip.theme.textOnInk
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 15; centerY: 15; radiusX: 6.5; radiusY: 6.5; startAngle: 200; sweepAngle: 50 }
                PathAngleArc { centerX: 15; centerY: 15; radiusX: 6.5; radiusY: 6.5; startAngle: 20; sweepAngle: 50; moveToStart: true }
            }
        }
        // a turn every 4s while it plays, in steps 5 times a second (not every frame); paused, it stops where it is
        Timer {
            interval: 200
            repeat: true
            running: strip.animate && strip.media.playing
            onTriggered: art.rotation = (art.rotation + 18) % 360
        }
    }

    Item {   // the line, laid out left to right and turned to read bottom to top
        id: window
        width: strip.textLen
        height: strip.band
        x: (strip.width - width) / 2
        y: play.y + play.height + 8 + (strip.textLen - height) / 2
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
            running: window.scrolls && strip.animate && strip.media.playing   // (it redraws the shell every frame)
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
