import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    Theme { id: theme }

    // Reserve the frame's space on every edge (the top band holds the bar), so windows tile inside
    // it. These panels draw nothing and take no input; the frame itself is drawn below.
    Variants {
        model: [
            { top: true, left: true, right: true, h: 56, w: 0, zone: 56 },
            { top: true, left: true, bottom: true, h: 0, w: 3, zone: 3 },
            { top: true, right: true, bottom: true, h: 0, w: 3, zone: 3 },
            { left: true, right: true, bottom: true, h: 3, w: 0, zone: 3 }
        ]
        delegate: PanelWindow {
            required property var modelData
            anchors { top: modelData.top === true; left: modelData.left === true
                      right: modelData.right === true; bottom: modelData.bottom === true }
            implicitHeight: modelData.h
            implicitWidth: modelData.w
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: modelData.zone
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "qs-frame-space"
            mask: Region {}
        }
    }

    PanelWindow {
        id: win
        property bool open: false

        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-shell"
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Only the bar items and the panel take mouse input; while the panel is open the whole
        // screen does, so a click outside closes it.
        mask: Region {
            regions: [
                Region { item: win.open ? backdrop : stats },
                Region { item: leftSection },
                Region { item: centerSection },
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

        // The frame around the monitor (the stats panel hangs from it, see Frame.qml)
        Frame {
            id: frame
            theme: theme
            panelW: stats.panelW
            panelH: stats.panelH
        }

        CenterSection {
            id: centerSection
            theme: theme
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
