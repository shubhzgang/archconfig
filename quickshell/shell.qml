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
        property bool clipOpen: false      // clipboard history (bottom left)
        property bool liveOpen: false      // live wallpaper links (bottom left)
        property bool opacityOpen: false   // opacity slider (bottom left)
        readonly property bool anyOpen: open || calOpen || launcherOpen || wallOpen || clipOpen || liveOpen || opacityOpen
        // the two top-left panels share the same spot, so only one can be open; the picker, the clipboard and the
        // live wallpaper list also take the keyboard, so they are alone too
        function closeOthers(except) {
            if (except !== "stats") open = false
            if (except !== "cal") calOpen = false
            if (except !== "launcher") launcherOpen = false
            if (except !== "wall") wallOpen = false
            if (except !== "clip") clipOpen = false
            if (except !== "live") liveOpen = false
            if (except !== "opacity") opacityOpen = false
        }
        onOpenChanged: if (open) closeOthers("stats")
        onCalOpenChanged: if (calOpen) closeOthers("cal")
        onLauncherOpenChanged: if (launcherOpen) closeOthers("launcher")
        onWallOpenChanged: if (wallOpen) closeOthers("wall")
        onClipOpenChanged: if (clipOpen) closeOthers("clip")
        onLiveOpenChanged: if (liveOpen) closeOthers("live")
        onOpacityOpenChanged: if (opacityOpen) closeOthers("opacity")

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
                Region { item: wallpaperButton },
                Region { item: clipboard },
                Region { item: clipboardButton },
                Region { item: live },
                Region { item: liveButton },
                Region { item: opacityPanel },
                Region { item: opacityButton }
            ]
        }

        Item {
            id: backdrop
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.closeOthers("")
            MouseArea { anchors.fill: parent; onClicked: win.closeOthers("") }
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
            function opacity(level: real): void { theme.setOpacity(level, true) }
        }

        IpcHandler {   // qs ipc call clipboard toggle|open|close
            target: "clipboard"
            function toggle(): void { win.clipOpen = !win.clipOpen }
            function open(): void { win.clipOpen = true }
            function close(): void { win.clipOpen = false }
        }

        IpcHandler {   // qs ipc call mpvpaper toggle|open|close
            target: "mpvpaper"
            function toggle(): void { win.liveOpen = !win.liveOpen }
            function open(): void { win.liveOpen = true }
            function close(): void { win.liveOpen = false }
        }

        IpcHandler {   // qs ipc call opacity toggle|open|close
            target: "opacity"
            function toggle(): void { win.opacityOpen = !win.opacityOpen }
            function open(): void { win.opacityOpen = true }
            function close(): void { win.opacityOpen = false }
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
            // the bottom-left panel: whichever of the three is furthest out
            readonly property var leftPanel: [clipboard, live, opacityPanel].reduce((a, b) => b.panelW > a.panelW ? b : a)
            clipW: leftPanel.panelW
            clipY: leftPanel.y
            clipH: leftPanel.height
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

        ClipboardPanel {
            id: clipboard
            theme: theme
            open: win.clipOpen
            onToggle: win.clipOpen = !win.clipOpen
        }

        LiveWallpaperPanel {
            id: live
            theme: theme
            open: win.liveOpen
            onToggle: win.liveOpen = !win.liveOpen
        }

        OpacityPanel {
            id: opacityPanel
            theme: theme
            open: win.opacityOpen
            onToggle: win.opacityOpen = !win.opacityOpen
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

        DockButton {   // opacity slider, at the very bottom
            id: opacityButton
            theme: theme
            glyph: 0xF1853
            slot: -2
            active: win.opacityOpen
            onClicked: win.opacityOpen = !win.opacityOpen
        }

        DockButton {   // wallpaper picker
            id: wallpaperButton
            theme: theme
            glyph: 0xF0E09
            slot: 0
            active: win.wallOpen
            onClicked: win.wallOpen = !win.wallOpen
        }

        DockButton {   // clipboard history
            id: clipboardButton
            theme: theme
            glyph: 0xF014C
            slot: 1
            active: win.clipOpen
            onClicked: win.clipOpen = !win.clipOpen
        }

        DockButton {   // live wallpaper
            id: liveButton
            theme: theme
            glyph: 0xF0FCF
            slot: 2
            active: win.liveOpen
            onClicked: win.liveOpen = !win.liveOpen
        }

        StatsCorner {
            id: stats
            theme: theme
            open: win.open
            onToggle: win.open = !win.open
        }
    }
}
