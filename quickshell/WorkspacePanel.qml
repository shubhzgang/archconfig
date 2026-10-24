import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Workspace overview, like Mission Control's spaces: grows out of the top band under the workspace
// dots, drawn by the frame like the other panels. The top row is the special workspaces (Super+S,
// Alt+1-4), the bottom row workspaces 1-10, empty or not. Each is a small picture of the screen: the
// wallpaper with its windows, captured when the overview opens, where they are. Click one to go there
// (a special one is shown or hidden, as its key does). Escape closes.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property var specials: [
        { name: "magic", label: "Super S" }, { name: "one", label: "Alt 1" }, { name: "two", label: "Alt 2" },
        { name: "three", label: "Alt 3" }, { name: "four", label: "Alt 4" }
    ]
    readonly property var normals: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(n => ({ id: n, label: String(n) }))

    readonly property int band: 48
    readonly property real thumbW: 300
    readonly property real thumbH: Math.round(thumbW * screenH / screenW)
    readonly property real labelH: 28
    readonly property real gap: 16
    readonly property real pad: 24
    readonly property real screenW: parent ? parent.width : 3840
    readonly property real screenH: parent ? parent.height : 2160

    readonly property real openW: 2 * pad + normals.length * (thumbW + gap) - gap
    readonly property real openH: 2 * pad + 2 * (thumbH + labelH) + gap
    readonly property real maxW: openW   // (its region's size, Frame.qml)
    readonly property real maxH: openH
    property real panelW: 0
    property real panelH: 0

    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
    width: panelW
    height: band + panelH
    clip: true

    // the windows' positions are only sent on request
    onOpenChanged: if (open) Hyprland.refreshToplevels()

    // Same shape of animation as the stats panel: eases out when opening, eases in when closing.
    states: State {
        name: "open"
        when: panel.open
        PropertyChanges { target: panel; panelW: panel.openW; panelH: panel.openH }
    }
    transitions: [
        Transition {
            from: ""; to: "open"
            NumberAnimation { property: "panelW"; duration: 520; easing.type: Easing.OutQuint }
            NumberAnimation { property: "panelH"; duration: 620; easing.type: Easing.OutQuint }
        },
        Transition {
            from: "open"; to: ""
            NumberAnimation { property: "panelW"; duration: 430; easing.type: Easing.InQuint }
            NumberAnimation { property: "panelH"; duration: 500; easing.type: Easing.InQuint }
        }
    ]

    MouseArea {   // a click on the panel, outside the workspaces, closes it
        anchors.fill: parent
        enabled: panel.open
        onClicked: panel.toggle()
    }

    component Space: Item {   // one workspace: its picture and its name
        id: space
        property string wsName       // Hyprland's name for it ("1", "special:magic")
        property string label
        signal picked()
        readonly property bool focused: Hyprland.focusedWorkspace?.name === wsName
        readonly property var windows: Hyprland.toplevels.values
            .filter(t => t.workspace?.name === wsName)
            .sort((a, b) => (a.lastIpcObject.floating ? 1 : 0) - (b.lastIpcObject.floating ? 1 : 0))
        width: panel.thumbW
        height: panel.thumbH + panel.labelH

        Rectangle {   // the ring round the focused one (and the hovered one, fainter)
            x: -4; y: -4
            width: panel.thumbW + 8; height: panel.thumbH + 8
            radius: 12
            color: "transparent"
            border.width: 2
            border.color: panel.theme.ink
            opacity: space.focused ? 1 : area.containsMouse ? 0.35 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        ClippingRectangle {
            width: panel.thumbW; height: panel.thumbH
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.35)
            Image {   // the wallpaper
                anchors.fill: parent
                source: panel.theme.wallpaper ? "file://" + panel.theme.wallpaper : ""
                sourceSize: Qt.size(panel.thumbW * 2, panel.thumbH * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Repeater {
                model: space.windows
                delegate: ScreencopyView {
                    required property var modelData
                    readonly property var at: modelData.lastIpcObject.at ?? [0, 0]
                    readonly property var size: modelData.lastIpcObject.size ?? [0, 0]
                    readonly property real scale: panel.thumbW / panel.screenW
                    x: at[0] * scale; y: at[1] * scale
                    width: size[0] * scale; height: size[1] * scale
                    captureSource: modelData.wayland
                    live: false
                }
            }
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            text: space.label
            color: panel.theme.ink
            opacity: space.focused ? 1 : 0.7
            font.family: "CodeNewRoman Nerd Font Mono"
            font.pixelSize: 15
            font.bold: space.focused
        }
        MouseArea {
            id: area
            width: panel.thumbW; height: panel.thumbH
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { space.picked(); panel.toggle() }
        }
    }

    Column {
        id: content
        // a fixed size, so nothing reflows while the panel grows; the panel clips it meanwhile
        x: panel.pad; y: panel.band + panel.pad
        width: panel.openW - 2 * panel.pad
        spacing: panel.gap
        opacity: panel.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {   // content fades in once the shape has (nearly) finished growing
            SequentialAnimation {
                PauseAnimation { duration: panel.open ? 300 : 0 }
                NumberAnimation { duration: panel.open ? 150 : 100 }
            }
        }
        // made when it opens (so the windows are captured then), gone once it has faded out
        readonly property bool made: panel.open || opacity > 0

        Row {   // the special workspaces
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: panel.gap
            Repeater {
                model: content.made ? panel.specials : []
                delegate: Space {
                    required property var modelData
                    wsName: "special:" + modelData.name
                    label: modelData.label
                    onPicked: Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.workspace.toggle_special("${modelData.name}")`])
                }
            }
        }
        Row {   // workspaces 1-10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: panel.gap
            Repeater {
                model: content.made ? panel.normals : []
                delegate: Space {
                    required property var modelData
                    wsName: String(modelData.id)
                    label: modelData.label
                    // a special workspace stays shown over the normal ones: hide the one that is out first
                    onPicked: Quickshell.execDetached(["sh", "-c", `
                        shown=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .specialWorkspace.name')
                        [ -n "$shown" ] && hyprctl dispatch "hl.dsp.workspace.toggle_special(\\"\${shown#special:}\\")"
                        hyprctl dispatch "hl.dsp.focus({ workspace = ${modelData.id} })"`])
                }
            }
        }
    }
}
