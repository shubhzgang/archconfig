import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Top-center section, replicating waybar's workspace dots: workspaces 1-10 always shown; the
// focused one is a wide pill, ones with windows and empty ones are different colors, hovering
// recolors, clicking switches.
Item {
    id: section
    required property var theme

    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 4 }   // inside the frame's top band
    height: 39
    width: row.implicitWidth

    Process { id: switcher }   // hyprctl: Hyprland's Lua config rejects the legacy `dispatch workspace N`
    function focusWorkspace(n) {
        switcher.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + n + " })"]
        switcher.running = true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: 10
            delegate: Item {
                id: dot
                required property int index
                readonly property int n: index + 1
                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === n)
                readonly property bool active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === n
                readonly property bool empty: !ws || ws.toplevels.values.length === 0
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

                    layer.enabled: !dot.empty || dot.active   // empty dots are flat: no drop shadow
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "black"
                        shadowOpacity: dot.active ? 0.75 : 0.65
                        shadowBlur: dot.active ? 0.1 : 0.2
                        shadowVerticalOffset: dot.active ? 2 : 3
                    }

                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.focusWorkspace(dot.n)
                }
            }
        }
    }
}
