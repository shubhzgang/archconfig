import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    Theme { id: theme }
    Media { id: media }
    Capture { id: capture }   // screenshots and screen recordings (ScreenshotPanel.qml)

    // A fullscreen window (a video, a game) hides the shell: the surfaces stay where they are, empty
    // and taking no input. (Hidden or covered surfaces get no frame callbacks, and Qt then leaves
    // them blank once they are shown again.) `hidden` (qs ipc call shell toggle) hides it the same
    // way and also gives up the frame's space, so the windows tile over the whole screen.
    property bool hidden: false
    readonly property bool fullscreen: hidden || (Hyprland.focusedWorkspace?.hasFullscreen ?? false)
    onFullscreenChanged: if (fullscreen) win.closeOthers("")

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
            exclusiveZone: root.hidden ? 0 : modelData.zone
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "qs-frame-space"
            mask: Region {}
        }
    }

    // The frame's inner shadow, on its own surface just below the shell's: Hyprland blurs behind the
    // shell's surface (for the glass style), and that blur must not reach the windows under the shadow.
    // The panels' regions draw their own (FrameRegion.qml), so this one only covers the rest.
    PanelWindow {
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-shadow"
        contentItem.visible: !fullscreen && !theme.flat
        mask: Region {}
        FrameShadow {
            anchors.fill: parent
            hole: frame.plainHole
            keepRects: frame.baseKeep
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
        property bool mediaOpen: false     // media player (middle left)
        property bool overviewOpen: false  // workspace overview (top middle)
        property bool powerOpen: false     // power menu (bottom left)
        property bool shotOpen: false      // screenshot panel (bottom left)
        readonly property bool anyOpen: open || calOpen || launcherOpen || wallOpen || clipOpen || liveOpen || mediaOpen || overviewOpen || powerOpen || shotOpen
        // the two top-left panels share the same spot, so only one can be open; the picker, the clipboard and the
        // live wallpaper list also take the keyboard, so they are alone too
        function closeOthers(except) {
            if (except !== "stats") open = false
            if (except !== "cal") calOpen = false
            if (except !== "launcher") launcherOpen = false
            if (except !== "wall") wallOpen = false
            if (except !== "clip") clipOpen = false
            if (except !== "live") liveOpen = false
            if (except !== "media") mediaOpen = false
            if (except !== "overview") overviewOpen = false
            if (except !== "power") powerOpen = false
            if (except !== "shot") shotOpen = false
        }
        onOpenChanged: if (open) closeOthers("stats")
        onCalOpenChanged: if (calOpen) closeOthers("cal")
        onLauncherOpenChanged: if (launcherOpen) closeOthers("launcher")
        onWallOpenChanged: if (wallOpen) closeOthers("wall")
        onClipOpenChanged: if (clipOpen) closeOthers("clip")
        onLiveOpenChanged: if (liveOpen) closeOthers("live")
        onMediaOpenChanged: if (mediaOpen) closeOthers("media")
        onOverviewOpenChanged: if (overviewOpen) closeOthers("overview")
        onPowerOpenChanged: if (powerOpen) closeOthers("power")
        onShotOpenChanged: if (shotOpen) closeOthers("shot")
        Connections {   // the player went away
            target: media
            function onPlayerChanged() { if (!media.player) win.mediaOpen = false }
        }

        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-shell"
        contentItem.visible: !fullscreen
        // (the panels, and the keyboard while one is open, are on their regions' surfaces: see the
        // FrameRegions below)

        // Only the dock buttons take mouse input; while a panel is open the whole screen does, so a
        // click outside closes it.
        mask: Region {
            regions: [
                Region { item: win.anyOpen ? backdrop : nothing },
                Region { item: themeButton },
                Region { item: wallpaperButton },
                Region { item: clipboardButton },
                Region { item: liveButton },
                Region { item: powerButton },
                Region { item: screenshotButton },
                Region { item: fullscreen ? nothing : backdrop; intersection: Intersection.Intersect }
            ]
        }

        Item { id: nothing }   // an empty input region

        Item {
            id: backdrop
            anchors.fill: parent
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

        IpcHandler {   // qs ipc call theme cycle|set <dark|normal|light>|style <paper|glass>|toggleStyle|shellColors <oled|matte|"">
            target: "theme"
            function cycle(): void { theme.cycleMode() }
            function shellColors(c: string): void { theme.setShellColors(c) }
            function set(mode: string): void { theme.setMode(mode) }
            function style(s: string): void { theme.setStyle(s) }
            function toggleStyle(): void { theme.setStyle(theme.glass ? "paper" : "glass") }
            function opacity(level: real): void { theme.setOpacity(level, true) }
            function checkLive(): void { theme.checkLive() }   // hypr/mpvpaper.sh: a live wallpaper started or ended
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

        IpcHandler {   // qs ipc call shell toggle|show|hide
            target: "shell"
            function toggle(): void { root.hidden = !root.hidden }
            function show(): void { root.hidden = false }
            function hide(): void { root.hidden = true }
        }

        IpcHandler {   // qs ipc call media toggle|open|close
            target: "media"
            function toggle(): void { win.mediaOpen = !win.mediaOpen && !!media.player }
            function open(): void { win.mediaOpen = !!media.player }
            function close(): void { win.mediaOpen = false }
        }

        IpcHandler {   // qs ipc call overview toggle|open|close
            target: "overview"
            function toggle(): void { win.overviewOpen = !win.overviewOpen }
            function open(): void { win.overviewOpen = true }
            function close(): void { win.overviewOpen = false }
        }

        IpcHandler {   // qs ipc call power toggle|open|close
            target: "power"
            function toggle(): void { win.powerOpen = !win.powerOpen }
            function open(): void { win.powerOpen = true }
            function close(): void { win.powerOpen = false }
        }

        IpcHandler {   // qs ipc call calendar toggle|open|close
            target: "calendar"
            function toggle(): void { win.calOpen = !win.calOpen }
            function open(): void { win.calOpen = true }
            function close(): void { win.calOpen = false }
        }

        // qs ipc call screenshot toggle|open|close|stop; while a capture is under way (a countdown,
        // a recording) toggle stops it instead, as the dock button does
        IpcHandler {
            target: "screenshot"
            function toggle(): void { if (capture.phase !== "idle") capture.stop(); else win.shotOpen = !win.shotOpen }
            function open(): void { win.shotOpen = true }
            function close(): void { win.shotOpen = false }
            function stop(): void { capture.stop() }
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
            // the bottom-left panel: whichever of them is furthest out
            readonly property var leftPanel: [clipboard, live, power, shot].reduce((a, b) => b.panelW > a.panelW ? b : a)
            clipW: leftPanel.panelW
            clipY: leftPanel.y
            clipH: leftPanel.height
            midW: mediaPanel.panelW
            midY: mediaPanel.y
            midH: mediaPanel.height
            wallMaxW: wallpaper.openW
            wallMaxH: wallpaper.openH
            topW: overview.panelW
            topH: overview.panelH
            topMaxW: overview.maxW
            topMaxH: overview.maxH
        }

        DockButton {   // power menu, at the bottom
            id: powerButton
            theme: theme
            glyph: 0xF0425
            slot: -1
            active: win.powerOpen
            onClicked: win.powerOpen = !win.powerOpen
        }

        Rectangle {   // a faint line between the power button and the theme button, in the gap between them
            x: (48 - width) / 2
            anchors { bottom: parent.bottom; bottomMargin: 18 + 44 + 8 }
            width: 22
            height: 1
            color: Qt.rgba(theme.ink.r, theme.ink.g, theme.ink.b, 0.25)
        }

        ThemeButton {
            id: themeButton
            theme: theme
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

        DockButton {   // screenshots: the countdown, then a blinking red dot while recording (a click stops it)
            id: screenshotButton
            theme: theme
            glyph: 0xF0100
            slot: 3
            active: win.shotOpen
            label: capture.phase === "counting" ? String(capture.remaining) : ""
            recording: capture.recording
            onClicked: if (capture.phase !== "idle") capture.stop(); else win.shotOpen = !win.shotOpen
        }

    }

    // ---- the panels' regions, each on its own surfaces (FrameRegion.qml, Frame.qml) ----

    FrameRegion {   // top right: the stats panel
        frame: frame
        theme: theme
        name: "stats"
        rect: frame.statsRect
        hole: frame.statsHole
        keepRects: frame.statsKeep
        active: win.open
        shown: !fullscreen
        onDismiss: win.closeOthers("")

        StatsCorner {
            id: stats
            theme: theme
            open: win.open
            maxH: frame.statsRect[3] - 60   // room below for its concave join and the shadows' overlap
            onToggle: win.open = !win.open
        }
    }

    FrameRegion {   // the left column: calendar and launcher (top), media (middle), clipboard, live wallpaper, power and screenshots (bottom)
        frame: frame
        theme: theme
        name: "left"
        rect: frame.leftRect
        hole: frame.leftHole
        keepRects: frame.leftKeep
        active: win.calOpen || win.launcherOpen || win.clipOpen || win.liveOpen || win.mediaOpen || win.powerOpen || win.shotOpen
        shown: !fullscreen
        onDismiss: win.closeOthers("")

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

        PowerPanel {
            id: power
            theme: theme
            open: win.powerOpen
            onToggle: win.powerOpen = !win.powerOpen
        }

        ScreenshotPanel {
            id: shot
            theme: theme
            capture: capture
            open: win.shotOpen
            onToggle: win.shotOpen = !win.shotOpen
        }

        MediaPanel {
            id: mediaPanel
            theme: theme
            media: media
            open: win.mediaOpen
            onToggle: win.mediaOpen = !win.mediaOpen
        }
    }

    FrameRegion {   // top middle: the workspace overview
        frame: frame
        theme: theme
        name: "top"
        rect: frame.topRect
        hole: frame.topHole
        keepRects: frame.topKeep
        active: win.overviewOpen
        shown: !fullscreen
        onDismiss: win.closeOthers("")

        WorkspacePanel {
            id: overview
            theme: theme
            open: win.overviewOpen
            onToggle: win.overviewOpen = !win.overviewOpen
        }
    }

    FrameRegion {   // bottom middle: the wallpaper picker
        frame: frame
        theme: theme
        name: "wall"
        rect: frame.wallRect
        hole: frame.wallHole
        keepRects: frame.wallKeep
        active: win.wallOpen
        shown: !fullscreen
        onDismiss: win.closeOthers("")

        WallpaperPanel {
            id: wallpaper
            theme: theme
            open: win.wallOpen
            onToggle: win.wallOpen = !win.wallOpen
        }
    }

    // The track playing, in the middle of the left band, on its own thin surface: its scrolling line
    // then only redraws this strip, not the screen-sized shell surface. Hidden with no player.
    PanelWindow {
        id: mediaWin
        anchors { top: true; bottom: true; left: true }
        implicitWidth: 48
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-media"
        readonly property bool shown: !fullscreen && !!media.player
        contentItem.visible: shown
        mask: Region { item: mediaWin.shown ? mediaStrip : null }

        MediaStrip {
            id: mediaStrip
            anchors.verticalCenter: parent.verticalCenter
            theme: theme
            media: media
            animate: mediaWin.shown
            active: win.mediaOpen
            onClicked: win.mediaOpen = !win.mediaOpen
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
        contentItem.visible: !fullscreen
        mask: Region {
            regions: [
                Region { item: leftSection },
                Region { item: leftSection.tipRect },
                Region { item: centerSection },
                Region { item: statsNumbers },
                Region { item: fullscreen ? null : barAll; intersection: Intersection.Intersect }
            ]
        }

        Item { id: barAll; anchors.fill: parent }

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
            onOverviewToggle: win.overviewOpen = !win.overviewOpen
        }

        StatsNumbers {
            id: statsNumbers
            theme: theme
            onToggle: win.open = !win.open
        }
    }
}
