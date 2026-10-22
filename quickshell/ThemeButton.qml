import QtQuick

// Button in the bottom-right corner that cycles the theme mode (dark, normal, light) of the shell's
// colors. When the mouse is in the corner, or the wallpaper picker is open, a tab grows out of the
// frame there (drawn by Frame.qml from panelW/panelH, like the panels) and the icon pops up in it.
// Hidden, only a thin strip along the frame's bottom band takes the mouse (to notice it arriving).
Item {
    id: root
    required property var theme
    property bool wallOpen: false
    readonly property bool shown: hover.hovered || wallOpen
    readonly property int tab: 72       // the tab's width and height
    readonly property int size: 44      // the icon's hit area, centered in the tab
    readonly property int side: 10      // the frame's bands (Frame.qml)
    property real panelW: 0
    property real panelH: 0

    anchors { right: parent.right; bottom: parent.bottom }
    width: shown ? 120 : 64
    height: shown ? 120 : 10

    HoverHandler { id: hover }

    // The tab rises and widens out of the corner; the icon pops in once it has grown, and goes
    // first when closing. (States + transitions: see StatsCorner.qml.)
    states: State {
        name: "shown"
        when: root.shown
        PropertyChanges { target: root; panelW: root.tab; panelH: root.tab }
        PropertyChanges { target: icon; opacity: 1; scale: 1 }
    }
    transitions: [
        Transition {
            from: ""; to: "shown"
            NumberAnimation { target: root; properties: "panelW,panelH"; duration: 450; easing.type: Easing.OutQuint }
            SequentialAnimation {
                PauseAnimation { duration: 300 }
                ParallelAnimation {
                    NumberAnimation { target: icon; property: "opacity"; duration: 160 }
                    NumberAnimation { target: icon; property: "scale"; duration: 220; easing.type: Easing.OutCubic }
                }
            }
        },
        Transition {
            from: "shown"; to: ""
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: icon; properties: "opacity,scale"; duration: 90 }
                }
                NumberAnimation { target: root; properties: "panelW,panelH"; duration: 380; easing.type: Easing.InQuint }
            }
        }
    ]

    Item {
        id: icon
        width: root.size; height: root.size
        anchors { right: parent.right; rightMargin: root.side + (root.tab - root.size) / 2
                  bottom: parent.bottom; bottomMargin: root.side + (root.tab - root.size) / 2 }
        opacity: 0
        scale: 0.6
        visible: opacity > 0
        Text {
            anchors.centerIn: parent
            // moon, half-and-half, sun
            text: String.fromCodePoint(root.theme.mode === "dark" ? 0xF0594 : root.theme.mode === "light" ? 0xF0599 : 0xF050E)
            color: area.containsMouse ? root.theme.hover : root.theme.ink
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 24
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.theme.cycleMode()
        }
    }
}
