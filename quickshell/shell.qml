import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Shapes

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

    // The frame's inner shadow, on its own surface just below the shell's: Hyprland blurs behind the
    // shell's surface (for the opacity slider), and that blur must not reach the windows under the shadow.
    // The stats corner's shadow is drawn by its own surface (below), so it is cut out here.
    PanelWindow {
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-shadow"
        mask: Region {}
        FrameShadow {
            anchors.fill: parent
            hole: frame.hole
            keepPath: frame.holeWithoutStats
        }
    }

    // The stats corner (statsRect) on its own surfaces: its shadow, and its piece of the frame with
    // the stats panel. The stats animation then only redraws this corner, not the whole screen (the
    // display runs on the integrated GPU). 40px larger than the corner on the left and below, so the
    // shadow's blur has the frame's outline beyond the corner to work from and meets the screen's
    // shadow without a seam.
    PanelWindow {
        id: statsShadowWin
        anchors { top: true; right: true }
        implicitWidth: frame.width - frame.statsRect[0] + 40
        implicitHeight: frame.statsRect[1] + frame.statsRect[3] + 40
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-stats-shadow"
        mask: Region {}
        FrameShadow {
            anchors.fill: parent
            hole: frame.statsHole
            originX: frame.width - width
            screenW: frame.width
            screenH: frame.height
            keepRect: frame.statsRect
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
                Region { item: win.anyOpen ? backdrop : nothing },
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

        Item { id: nothing }   // an empty input region

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

    }

    // The stats corner's piece of the frame and the stats panel (see statsShadowWin above).
    PanelWindow {
        id: statsWin
        anchors { top: true; right: true }
        implicitWidth: frame.width - frame.statsRect[0]
        implicitHeight: frame.statsRect[1] + frame.statsRect[3]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-stats"
        mask: Region { item: stats }

        Item {   // the frame inside the corner: everything outside statsHole, clipped to statsRect
            x: frame.statsRect[0] - (frame.width - statsWin.width)
            y: frame.statsRect[1]
            width: frame.statsRect[2]
            height: frame.statsRect[3]
            clip: true
            Shape {
                x: -frame.statsRect[0]
                y: -frame.statsRect[1]
                width: frame.width; height: frame.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillRule: ShapePath.OddEvenFill
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillGradient: LinearGradient {   // the frame's gradient, in screen coordinates
                        x1: 0; y1: 0; x2: frame.width; y2: 0
                        GradientStop { position: 0.0; color: theme.barEnd }
                        GradientStop { position: 0.5; color: theme.barStart }
                        GradientStop { position: 1.0; color: theme.barEnd }
                    }
                    PathSvg {
                        path: `M -20 -20 L ${frame.width + 20} -20 L ${frame.width + 20} ${frame.height + 20} `
                            + `L -20 ${frame.height + 20} Z ` + frame.statsHole
                    }
                }
            }
        }

        StatsCorner {
            id: stats
            theme: theme
            open: win.open
            maxH: frame.statsRect[3] - 20 - 40   // room below for its concave join and the shadows' overlap
            onToggle: win.open = !win.open
        }
    }

    // The bar's own items (clock, tray, workspace dots, stats numbers) on a thin surface above the
    // shell's: they change every second, and on the screen-sized shell surface each change redrew and
    // recomposited the whole screen (the display runs on the integrated GPU). Tall enough for the
    // left section's tooltips, which hang below the bar; only the items take the mouse.
    PanelWindow {
        id: barWin
        anchors { top: true; left: true; right: true }
        implicitHeight: 120
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-bar"
        mask: Region {
            regions: [
                Region { item: leftSection },
                Region { item: leftSection.tipRect },
                Region { item: centerSection },
                Region { item: statsNumbers }
            ]
        }

        LeftSection {
            id: leftSection
            theme: theme
            win: barWin
            onCalendarToggle: win.calOpen = !win.calOpen
            onLauncherToggle: win.launcherOpen = !win.launcherOpen
        }

        CenterSection {
            id: centerSection
            theme: theme
        }

        StatsNumbers {
            id: statsNumbers
            theme: theme
            onToggle: win.open = !win.open
        }
    }
}
