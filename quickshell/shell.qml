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
            { top: true, left: true, right: true, h: 48, w: 0, zone: 48 },
            { top: true, left: true, bottom: true, h: 0, w: 48, zone: 48 },
            { top: true, right: true, bottom: true, h: 0, w: 10, zone: 10 },
            { left: true, right: true, bottom: true, h: 10, w: 0, zone: 10 }
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
        property bool open: false          // stats panel
        property bool calOpen: false       // calendar panel
        property bool launcherOpen: false  // app launcher panel
        property bool wallOpen: false      // wallpaper picker (bottom)
        readonly property bool anyOpen: open || calOpen || launcherOpen || wallOpen
        // the two left panels share the same spot, so only one can be open; the picker also takes the keyboard, so it is alone too
        onCalOpenChanged: if (calOpen) { launcherOpen = false; wallOpen = false }
        onLauncherOpenChanged: if (launcherOpen) { calOpen = false; wallOpen = false }
        onWallOpenChanged: if (wallOpen) { open = false; calOpen = false; launcherOpen = false }
        onOpenChanged: if (open) wallOpen = false

        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-shell"
        WlrLayershell.keyboardFocus: anyOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Only the bar items and the panel take mouse input; while the panel is open the whole
        // screen does, so a click outside closes it.
        mask: Region {
            regions: [
                Region { item: win.anyOpen ? backdrop : stats },
                Region { item: leftSection },
                Region { item: centerSection },
                Region { item: leftSection.tipRect },
                Region { item: calendar },
                Region { item: launcher },
                Region { item: wallpaper },
                Region { item: themeButton },
                Region { item: wallpaperButton }
            ]
        }

        Item {
            id: backdrop
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: { win.open = false; win.calOpen = false; win.launcherOpen = false; win.wallOpen = false }
            MouseArea { anchors.fill: parent; onClicked: { win.open = false; win.calOpen = false; win.launcherOpen = false; win.wallOpen = false } }
        }

        IpcHandler {   // qs ipc call stats toggle|open|close|sampling <s> <points>
            target: "stats"
            function toggle(): void { win.open = !win.open }
            function open(): void { win.open = true }
            function close(): void { win.open = false }
            function sampling(interval: int, points: int): void { stats.setSampling(interval, points) }
        }

        IpcHandler {   // qs ipc call launcher toggle|open|close
            target: "launcher"
            function toggle(): void { win.launcherOpen = !win.launcherOpen }
            function open(): void { win.launcherOpen = true }
            function close(): void { win.launcherOpen = false }
        }

        IpcHandler {   // qs ipc call wallpaper toggle|open|close
            target: "wallpaper"
            function toggle(): void { win.wallOpen = !win.wallOpen }
            function open(): void { win.wallOpen = true }
            function close(): void { win.wallOpen = false }
        }

        IpcHandler {   // qs ipc call theme cycle|set <dark|normal|light>
            target: "theme"
            function cycle(): void { theme.cycleMode() }
            function set(mode: string): void { theme.setMode(mode) }
        }

        IpcHandler {   // qs ipc call calendar toggle|open|close
            target: "calendar"
            function toggle(): void { win.calOpen = !win.calOpen }
            function open(): void { win.calOpen = true }
            function close(): void { win.calOpen = false }
        }

        // The frame around the monitor (the panels hang from it, see Frame.qml)
        Frame {
            id: frame
            theme: theme
            panelW: stats.panelW
            panelH: stats.panelH
            leftW: Math.max(calendar.panelW, launcher.panelW)
            leftH: Math.max(calendar.panelH, launcher.panelH)
            bottomW: wallpaper.panelW
            bottomH: wallpaper.panelH
        }

        CalendarPanel {
            id: calendar
            theme: theme
            open: win.calOpen
            onToggle: win.calOpen = !win.calOpen
        }

        LauncherPanel {
            id: launcher
            theme: theme
            open: win.launcherOpen
            onToggle: win.launcherOpen = !win.launcherOpen
        }

        WallpaperPanel {
            id: wallpaper
            theme: theme
            open: win.wallOpen
            onToggle: win.wallOpen = !win.wallOpen
        }

        CenterSection {
            id: centerSection
            theme: theme
        }

        LeftSection {
            id: leftSection
            theme: theme
            win: win
            onCalendarToggle: win.calOpen = !win.calOpen
            onLauncherToggle: win.launcherOpen = !win.launcherOpen
        }

        ThemeButton {
            id: themeButton
            theme: theme
        }

        WallpaperButton {
            id: wallpaperButton
            theme: theme
            active: win.wallOpen
            onClicked: win.wallOpen = !win.wallOpen
        }

        StatsCorner {
            id: stats
            theme: theme
            open: win.open
            onToggle: win.open = !win.open
        }
    }
}
