import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    Theme { id: theme }

    PanelWindow {
        id: win
        property bool open: false

        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-shell"
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Only the corner takes mouse input; while it is open the whole screen does, so a
        // click outside closes it.
        mask: Region {
            regions: [
                Region { item: win.open ? backdrop : stats },
                Region { item: leftSection },
                Region { item: leftSection.tipRect },
                Region { item: leftSection.calendarRect }
            ]
        }

        Item {
            id: backdrop
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.open = false
            MouseArea { anchors.fill: parent; onClicked: win.open = false }
        }

        IpcHandler {   // qs ipc call stats toggle|open|close|sampling <s> <points>
            target: "stats"
            function toggle(): void { win.open = !win.open }
            function open(): void { win.open = true }
            function close(): void { win.open = false }
            function sampling(interval: int, points: int): void { stats.setSampling(interval, points) }
        }

        // Soft shadow under the corner, like waybar's `box-shadow: 0 2px 5px rgba(0,0,0,.85)`.
        // A hidden twin of the corner casts it (the corner itself is clipped to its bounds).
        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 10 }
            width: stats.width
            height: stats.height
            radius: stats.radius
            color: "black"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.85
                shadowBlur: 0.85
                shadowVerticalOffset: 4
            }
        }

        Rectangle {   // shadow twin for the left section (see the corner's)
            anchors { top: parent.top; left: parent.left; topMargin: 10; leftMargin: 10 }
            width: leftSection.width
            height: leftSection.height
            radius: leftSection.radius
            color: "black"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.85
                shadowBlur: 0.85
                shadowVerticalOffset: 4
            }
        }

        LeftSection {
            id: leftSection
            theme: theme
            win: win
        }

        StatsCorner {
            id: stats
            theme: theme
            open: win.open
            onToggle: win.open = !win.open
        }
    }
}
