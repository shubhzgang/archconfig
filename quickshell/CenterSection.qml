import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Top-center section, replicating waybar's workspace dots: workspaces 1-10 always shown; the
// focused one is a wide pill, ones with windows and empty ones are different colors, hovering
// recolors, clicking switches. Clicking beside them (not on a dot) opens the workspace overview.
// While a special workspace (Super+S, Alt+1-4) is shown, its five dots slide out to the left.
Item {
    id: section
    required property var theme
    signal overviewToggle()

    readonly property var specials: ["magic", "one", "two", "three", "four"]   // Super+S, Alt+1-4
    // the special workspace shown on the focused monitor ("" when none); Hyprland reports each
    // toggle as an `activespecial` event, and the monitors are refetched to pick it up
    readonly property string special: (Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name ?? "").replace("special:", "")
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "activespecial") Hyprland.refreshMonitors() }
    }

    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 4 }   // inside the frame's top band
    height: 39
    // 120px beside the dots on each side, plus the special dots when out (on both sides, to keep 1-10 centered)
    width: row.implicitWidth + 2 * (120 + specialGroup.width)

    MouseArea {   // beside the dots (they are above it and take their own clicks)
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: section.overviewToggle()
    }

    Process { id: switcher }   // hyprctl: Hyprland's Lua config rejects the legacy `dispatch workspace N`
    function focusWorkspace(n) {
        switcher.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + n + " })"]
        switcher.running = true
    }

    component WsDot: Item {
        id: dot
        property bool active
        property bool empty
        signal clicked()
        readonly property bool hovered: area.containsMouse

        // waybar: 15px dot (30px when focused) + 2px padding each side, 3px margins
        width: (active ? 34 : 19) + 6
        height: 39
        Behavior on width { NumberAnimation { duration: 170 } }

        Rectangle {
            id: body
            anchors.centerIn: parent
            width: dot.active ? 34 : 19
            height: 19
            radius: dot.active ? 10 : height / 2
            Behavior on width { NumberAnimation { duration: 170 } }
            Behavior on radius { NumberAnimation { duration: 170 } }
            // colors as in waybar's CSS: focused = color1 (color2 on hover), others turn
            // color1 on hover; otherwise color2 with windows, color3 when empty
            color: dot.active ? (dot.hovered ? section.theme.accent2 : section.theme.accent)
                 : dot.hovered ? section.theme.accent
                 : dot.empty ? section.theme.accent3 : section.theme.accent2
            Behavior on color { ColorAnimation { duration: 300 } }

            RectangularShadow {
                anchors.fill: parent; z: -1
                visible: !dot.empty || dot.active   // empty dots are flat: no drop shadow
                radius: parent.radius; offset: Qt.vector2d(0, dot.active ? 2 : 3); blur: dot.active ? 1.4 : 2.9; spread: 1
                color: Qt.rgba(0, 0, 0, dot.active ? 0.75 : 0.65)
            }

        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dot.clicked()
        }
    }

    Item {   // the special workspaces' dots, sliding out from behind workspace 1's, after a divider
        id: specialGroup
        property real progress: section.special !== "" ? 1 : 0
        Behavior on progress { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        anchors { right: row.left; verticalCenter: row.verticalCenter }
        width: (specialRow.implicitWidth + 12) * progress
        height: 39
        clip: true
        opacity: progress
        visible: progress > 0

        Rectangle {   // thin divider, as between the stats numbers, centered in the 12px gap
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            width: 1; height: 19
            color: Qt.rgba(section.theme.ink.r, section.theme.ink.g, section.theme.ink.b, 0.2)
        }

        Row {
            id: specialRow
            anchors { right: parent.right; rightMargin: 12 }
            Repeater {
                model: section.specials
                delegate: WsDot {
                    required property string modelData
                    readonly property var ws: Hyprland.workspaces.values.find(w => w.name === "special:" + modelData)
                    active: section.special === modelData
                    empty: !ws || ws.toplevels.values.length === 0
                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.workspace.toggle_special("${modelData}")`])
                }
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: 10
            delegate: WsDot {
                required property int index
                readonly property int n: index + 1
                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === n)
                active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === n
                empty: !ws || ws.toplevels.values.length === 0
                onClicked: section.focusWorkspace(n)
            }
        }
    }
}
