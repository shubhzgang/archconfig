import QtQuick
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
        mask: Region { item: win.open ? backdrop : stats }

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

        StatsCorner {
            id: stats
            theme: theme
            open: win.open
            onToggle: win.open = !win.open
        }
    }
}
