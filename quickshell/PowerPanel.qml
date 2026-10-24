import QtQuick
import QtQuick.Effects
import Quickshell

// Power menu: slides out of the bottom of the frame's left band (from the power button), drawn by the
// frame like the clipboard list. Lock, sleep, log out, restart and shut down. Left/Right or the mouse
// select (hovering selects), Enter or a click runs the selected one, as does its key (L, Z, E, R, S).
// Escape closes.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int band: 48      // the frame's left band (Frame.qml)
    readonly property int side: 10      // its bottom band
    readonly property var actions: [
        { label: "Lock", key: Qt.Key_L, glyph: 0xF033E, command: ["hyprlock"] },
        { label: "Sleep", key: Qt.Key_Z, glyph: 0xF0904, command: ["sh", "-c", "systemctl suspend || loginctl suspend"] },
        { label: "Log out", key: Qt.Key_E, glyph: 0xF0343, command: ["sh", "-c", "pkill Hyprland || loginctl terminate-user $USER"] },
        { label: "Restart", key: Qt.Key_R, glyph: 0xF0709, command: ["sh", "-c", "systemctl reboot || loginctl reboot"] },
        { label: "Shut down", key: Qt.Key_S, glyph: 0xF0425, command: ["sh", "-c", "systemctl poweroff || loginctl poweroff"] }
    ]
    readonly property int cardW: 128
    readonly property int cardH: 120
    readonly property int gap: 12
    readonly property int pad: 16
    readonly property real openW: 2 * pad + actions.length * (cardW + gap) - gap
    readonly property real openH: 2 * pad + cardH
    property real panelW: 0
    property int current: 0

    function run(action) {
        panel.toggle()
        Quickshell.execDetached(action.command)
    }
    onOpenChanged: if (open) { current = 0; content.forceActiveFocus() }

    // in the bottom-left corner of the free area; only the width animates
    anchors { left: parent.left; leftMargin: band; bottom: parent.bottom; bottomMargin: side }
    width: panelW
    height: openH
    clip: true

    // Slides out with an ease-out and back with an ease-in, the content fading in once it has (nearly)
    // finished and going first when closing, as the clipboard list does (ListPanel.qml).
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

    Row {
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
            const action = panel.actions.find(a => a.key === event.key)
            if (action) { panel.run(action); event.accepted = true }
        }

        Repeater {
            model: panel.actions
            delegate: Item {
                id: card
                required property var modelData
                required property int index
                width: panel.cardW
                height: panel.cardH
                readonly property bool selected: index === panel.current
                // the selected one is picked up, as in the launcher: it rises 6px and shifts 4px right,
                // with a deeper shadow
                property real lift: selected ? 1 : 0
                Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    transform: Translate { x: 4 * card.lift; y: -6 * card.lift }
                    radius: 10
                    color: card.selected ? panel.theme.accent : panel.theme.card
                    Behavior on color { ColorAnimation { duration: 150 } }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.33 + 0.27 * card.lift)
                        shadowBlur: 0.45 + 0.15 * card.lift
                        shadowVerticalOffset: 3 + card.lift
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
                    onPositionChanged: panel.current = card.index   // hovering selects
                    onClicked: panel.run(card.modelData)
                }
            }
        }
    }
}
