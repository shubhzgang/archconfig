import QtQuick
import QtQuick.Effects
import Quickshell

// Screenshot panel: slides out of the bottom of the frame's left band, like the power menu. Photo
// (region, window, screen) and video (region, screen) cards, and chips for the delay and the
// recording's audio (Capture.qml does the work). Left/Right or the mouse select (hovering selects),
// Enter or a click runs the selected one, as does its key (R, W, S; Shift+R, Shift+S for video);
// D steps the delay, A toggles the audio. Escape closes.
Item {
    id: panel
    required property var theme
    required property var capture
    property bool open: false
    signal toggle()

    readonly property int band: 48      // the frame's left band (Frame.qml)
    readonly property int side: 10      // its bottom band
    readonly property var actions: [
        { kind: "photo", mode: "region", label: "Region", key: Qt.Key_R, shift: false, glyph: 0xF0A6C },
        { kind: "photo", mode: "window", label: "Window", key: Qt.Key_W, shift: false, glyph: 0xF0614 },
        { kind: "photo", mode: "screen", label: "Screen", key: Qt.Key_S, shift: false, glyph: 0xF0379 },
        { kind: "video", mode: "region", label: "Region", key: Qt.Key_R, shift: true, glyph: 0xF0A6C },
        { kind: "video", mode: "screen", label: "Screen", key: Qt.Key_S, shift: true, glyph: 0xF0379 }
    ]
    readonly property int cardW: 128
    readonly property int cardH: 120
    readonly property int gap: 12
    readonly property int groupGap: 28  // between the photo and the video cards
    readonly property int headH: 28     // a group's title above its cards
    readonly property int chipH: 36
    readonly property int pad: 16
    readonly property real openW: 2 * pad + actions.length * (cardW + gap) - 2 * gap + groupGap
    readonly property real openH: 2 * pad + headH + cardH + gap + chipH
    property real panelW: 0
    property int current: 0

    function run(action) {
        panel.toggle()
        panel.capture.start(action.kind, action.mode)
    }
    onOpenChanged: if (open) { current = 0; content.forceActiveFocus() }

    // in the bottom-left corner of the free area; only the width animates
    anchors { left: parent.left; leftMargin: band; bottom: parent.bottom; bottomMargin: side }
    width: panelW
    height: openH
    clip: true

    // Slides out with an ease-out and back with an ease-in, the content fading in once it has (nearly)
    // finished and going first when closing, as the power menu does (PowerPanel.qml).
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

    // a card, as in the power menu: the selected one is picked up (it rises 6px and shifts 4px
    // right, with a deeper shadow)
    component ActionCard: Item {
        id: card
        required property var modelData
        required property int index
        readonly property int at: modelData.kind === "photo" ? index : index + 3   // index in panel.actions
        readonly property bool selected: at === panel.current
        width: panel.cardW
        height: panel.cardH
        property real lift: selected ? 1 : 0
        Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            transform: Translate { x: 4 * card.lift; y: -6 * card.lift }
            radius: 10
            color: card.selected ? panel.theme.accent : panel.theme.card
            Behavior on color { ColorAnimation { duration: 150 } }
            RectangularShadow {
                visible: panel.theme.shadows
                anchors.fill: parent; z: -1
                radius: parent.radius; offset: Qt.vector2d(0, 3 + card.lift); blur: 6.5 + 2.2 * card.lift; spread: 1
                color: Qt.rgba(0, 0, 0, (0.33 + 0.27 * card.lift) * parent.color.a)
            }
            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String.fromCodePoint(card.modelData.glyph)
                    color: panel.theme.dark
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 40
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: card.modelData.label
                    color: panel.theme.dark
                    font.family: "CodeNewRoman Nerd Font Mono"
                    font.pixelSize: 15
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: panel.current = card.at   // hovering selects
            onClicked: panel.run(card.modelData)
        }
    }

    component GroupTitle: Text {
        height: panel.headH
        color: panel.theme.ink
        font.family: "CodeNewRoman Nerd Font Mono"
        font.pixelSize: 15
    }

    component Chip: Rectangle {
        id: chip
        property int glyph
        property string label
        signal clicked()
        width: chipRow.implicitWidth + 32
        height: panel.chipH
        radius: height / 2
        color: area.containsMouse ? panel.theme.accent : panel.theme.card
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(chip.glyph)
                color: panel.theme.dark
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 18
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: panel.theme.dark
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 15
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Column {
        id: content
        x: panel.pad; y: panel.pad
        spacing: panel.gap
        opacity: 0
        visible: opacity > 0

        Keys.onEscapePressed: panel.toggle()
        Keys.onLeftPressed: panel.current = Math.max(0, panel.current - 1)
        Keys.onRightPressed: panel.current = Math.min(panel.actions.length - 1, panel.current + 1)
        Keys.onReturnPressed: panel.run(panel.actions[panel.current])
        Keys.onEnterPressed: panel.run(panel.actions[panel.current])
        Keys.onPressed: event => {
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0
            const action = panel.actions.find(a => a.key === event.key && a.shift === shift)
            if (action) panel.run(action)
            else if (event.key === Qt.Key_D) panel.capture.cycleDelay()
            else if (event.key === Qt.Key_A) panel.capture.toggleAudio()
            else return
            event.accepted = true
        }

        Row {
            spacing: panel.groupGap
            Column {
                GroupTitle { text: "Photo" }
                Row {
                    spacing: panel.gap
                    Repeater {
                        model: panel.actions.slice(0, 3)
                        delegate: ActionCard {}
                    }
                }
            }
            Column {
                GroupTitle { text: "Video" }
                Row {
                    spacing: panel.gap
                    Repeater {
                        model: panel.actions.slice(3)
                        delegate: ActionCard {}
                    }
                }
            }
        }

        Row {
            spacing: panel.gap
            Chip {
                glyph: 0xF051B
                label: "Delay: " + (panel.capture.delay ? panel.capture.delay + "s" : "off")
                onClicked: panel.capture.cycleDelay()
            }
            Chip {
                glyph: panel.capture.audio ? 0xF057E : 0xF0581
                label: "Audio: " + (panel.capture.audio ? "on" : "off")
                onClicked: panel.capture.toggleAudio()
            }
        }
    }
}
