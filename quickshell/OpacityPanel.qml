import QtQuick

// Opacity slider that slides out of the bottom of the frame's left band, drawn by the frame like the
// clipboard panel. Sets how opaque the shell's bar, panels and cards are, from 10% to fully opaque.
// Drag the slider, click on it, or use Left/Right; Escape closes.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int band: 48      // the frame's left band (Frame.qml)
    readonly property int side: 10      // its bottom band
    readonly property real openW: 480
    readonly property real openH: 130
    property real panelW: 0

    readonly property real minLevel: 0.10
    readonly property real step: 0.05

    // in the bottom-left corner of the free area; only the width animates
    anchors { left: parent.left; leftMargin: band; bottom: parent.bottom; bottomMargin: side }
    width: panelW
    height: openH
    clip: true

    function nudge(by) { theme.setOpacity(Math.max(minLevel, Math.min(1, theme.opacityLevel + by)), true) }
    onOpenChanged: if (open) keys.forceActiveFocus()

    // slides out of the band with an ease-out, and back with an ease-in; the content fades in once it
    // has (nearly) finished, and goes first when closing (states + transitions, see StatsCorner.qml)
    states: State {
        name: "open"
        when: panel.open
        PropertyChanges { target: panel; panelW: panel.openW }
        PropertyChanges { target: content; opacity: 1 }
    }
    transitions: [
        Transition {
            from: ""; to: "open"
            ParallelAnimation {
                NumberAnimation { target: panel; property: "panelW"; duration: 520; easing.type: Easing.OutQuint }
                SequentialAnimation {
                    PauseAnimation { duration: 420 }
                    NumberAnimation { target: content; property: "opacity"; duration: 160 }
                }
            }
        },
        Transition {
            from: "open"; to: ""
            SequentialAnimation {
                NumberAnimation { target: content; property: "opacity"; duration: 90 }
                NumberAnimation { target: panel; property: "panelW"; duration: 400; easing.type: Easing.InQuint }
            }
        }
    ]

    Item {
        id: content
        x: 24; y: 20
        width: panel.openW - 48      // fixed, so nothing reflows while the panel slides out
        height: panel.openH - 40
        opacity: 0
        visible: opacity > 0

        Item {
            id: keys
            anchors.fill: parent
            Keys.onEscapePressed: panel.toggle()
            Keys.onLeftPressed: panel.nudge(-panel.step)
            Keys.onRightPressed: panel.nudge(panel.step)
        }

        Text {
            text: "Opacity"
            color: panel.theme.ink
            font.family: "CodeNewRoman Nerd Font Mono"
            font.pixelSize: 19
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            text: Math.round(panel.theme.opacityLevel * 100) + "%"
            color: panel.theme.ink
            font.family: "CodeNewRoman Nerd Font Mono"
            font.pixelSize: 19
        }

        Item {
            id: slider
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 40
            readonly property real frac: (panel.theme.opacityLevel - panel.minLevel) / (1 - panel.minLevel)

            Rectangle {   // track
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 8; radius: 4
                color: Qt.rgba(panel.theme.ink.r, panel.theme.ink.g, panel.theme.ink.b, 0.25)
                Rectangle {   // the part up to the handle
                    width: parent.width * slider.frac
                    height: parent.height; radius: parent.radius
                    color: panel.theme.ink
                }
            }
            Rectangle {   // handle
                x: (slider.width - width) * slider.frac
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26; radius: 13
                color: panel.theme.ink
                border.width: 3
                border.color: panel.theme.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function setFrom(x, final) {
                    const f = Math.max(0, Math.min(1, (x - 13) / (width - 26)))
                    const v = panel.minLevel + f * (1 - panel.minLevel)
                    panel.theme.setOpacity(Math.round(v / panel.step) * panel.step, final)
                }
                onPressed: mouse => setFrom(mouse.x, false)
                onPositionChanged: mouse => setFrom(mouse.x, false)
                onReleased: mouse => setFrom(mouse.x, true)
            }
        }
    }
}
