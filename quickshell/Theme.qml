import QtQuick
import Quickshell
import Quickshell.Io

// Colors from the active wallpaper scheme (pywal files), refreshed once a second so a
// wallpaper change shows up without restarting the shell.
Item {
    id: root

    property color accent: "#4a8fb5"       // color1: active window border
    property color ink: "#d8dce4"          // color7: light text
    property color hover: "#ffb59a"        // color9: text on hover
    property color accent2: "#5d629b"      // color2: workspace dot with windows
    property color accent3: "#e12c97"      // color3: empty workspace dot
    property color dark: "#10141a"         // scheme background: dark text on light cards
    property color textOnInk: "#10141a"        // text on a fill of the `ink` color
    property color barStart: "#742306"     // waybar side-section gradient ends
    property color barEnd: "#1c375f"
    property color card: "#c3cadb"         // pale blue-grey card, as in the sysstats panel (darker or lighter per mode)
    property var series: ["#e06c75", "#61afef", "#98c379", "#e5c07b", "#c678dd", "#56b6c2"]

    // colors fade into each other (a wallpaper preview, or a new wallpaper being applied)
    Behavior on accent { ColorAnimation { duration: 250 } }
    Behavior on ink { ColorAnimation { duration: 250 } }
    Behavior on hover { ColorAnimation { duration: 250 } }
    Behavior on accent2 { ColorAnimation { duration: 250 } }
    Behavior on accent3 { ColorAnimation { duration: 250 } }
    Behavior on dark { ColorAnimation { duration: 250 } }
    Behavior on textOnInk { ColorAnimation { duration: 250 } }
    Behavior on card { ColorAnimation { duration: 250 } }
    Behavior on barStart { ColorAnimation { duration: 250 } }
    Behavior on barEnd { ColorAnimation { duration: 250 } }

    function darken(c, t) { return Qt.rgba(c.r * (1 - t), c.g * (1 - t), c.b * (1 - t), 1) }
    // same as the dark, saturated bar ends in scripts/bar-colors.py
    function vividDark(hex) {
        const c = Qt.color(hex)
        if (c.hslSaturation < 0.1) return Qt.hsla(0, c.hslSaturation, 0.24, 1)   // a grey stays grey
        return Qt.hsla(c.hslHue, Math.min(0.9, Math.max(c.hslSaturation * 1.3, 0.55)), 0.24, 1)
    }

    // ---- opacity: how see-through the frame (the bar and panels) and the cards are, 0.1 to 1 ----
    property real opacityLevel: 1.0
    readonly property string opacityFile: Quickshell.env("HOME") + "/.cache/quickshell-opacity"
    function setOpacity(level, save) {   // save: the slider was let go (or a key pressed), not mid-drag
        level = Math.max(0.1, Math.min(1, level))
        if (level !== opacityLevel || !blurSynced) syncBlur(level)
        opacityLevel = level
        applyTheme()
        if (save) savedOpacity.setText(String(opacityLevel))
    }
    // Hyprland blurs behind the shell only where it is at least this opaque: just under the frame's
    // own opacity, so the frame's fainter anti-aliased edge pixels aren't blurred (the blur pulled
    // light from under the frame into a thin line along its curves). Same rules as in hyprland.lua,
    // which reads the saved level when the config is reloaded: the wallpaper picker shows the windows
    // behind it, the rest only the (cached) wallpaper.
    property bool blurSynced: false
    function syncBlur(level) {
        blurSynced = true
        const alpha = (level * 0.9).toFixed(3)
        Quickshell.execDetached(["hyprctl", "eval", "hl.layer_rule({ name = \"quickshell-blur\", "
            + "match = { namespace = \"^qs-(shell|region-stats|region-left)$\" }, blur = true, xray = true, ignore_alpha = " + alpha + " })"])
        Quickshell.execDetached(["hyprctl", "eval", "hl.layer_rule({ name = \"quickshell-blur-wall\", "
            + "match = { namespace = \"^qs-region-wall$\" }, blur = true, xray = false, ignore_alpha = " + alpha + " })"])
    }
    FileView {
        id: savedOpacity
        path: root.opacityFile
        printErrors: false
        onLoaded: {
            const v = parseFloat(text())
            if (!isNaN(v)) root.setOpacity(v, false)
        }
    }
    function alpha(c) { const q = Qt.color(c); return Qt.rgba(q.r, q.g, q.b, opacityLevel) }

    // ---- theme mode: the same palette, darker or lighter (Quickshell only) ----
    // dark: the bar and cards go dark, light text on them; light: the bar and cards go pale, dark text.
    property string mode: "normal"      // dark | normal | light
    readonly property string modeFile: Quickshell.env("HOME") + "/.cache/quickshell-theme-mode"
    function setMode(m) {
        if (m !== "dark" && m !== "normal" && m !== "light") return
        mode = m
        savedMode.setText(m)
        applyTheme()
    }
    function cycleMode() { setMode({ dark: "normal", normal: "light", light: "dark" }[mode]) }
    FileView {
        id: savedMode
        path: root.modeFile
        printErrors: false
        onLoaded: { root.mode = ["dark", "light"].includes(text().trim()) ? text().trim() : "normal"; root.applyTheme() }
    }
    function tone(hex) {   // a bar gradient end in the current mode
        const c = Qt.color(hex), h = Math.max(c.hslHue, 0)
        if (mode === "dark") return Qt.hsla(h, c.hslSaturation, c.hslLightness * 0.5, 1)
        if (mode === "light") return Qt.hsla(h, Math.min(c.hslSaturation, 0.75), 0.74, 1)
        return c
    }

    // ---- style: paper (opaque, like the cards on a desk) or glass (see-through and blurred, with a
    // thin light edge). Also sets how opaque kitty is, through a Hyprland window rule that hyprland.lua
    // makes from the same saved file when its config is reloaded.
    property string style: "paper"      // paper | glass
    readonly property bool glass: style === "glass"
    readonly property string styleFile: Quickshell.env("HOME") + "/.cache/quickshell-style"
    function setStyle(s) {
        if (s !== "paper" && s !== "glass") return
        style = s
        savedStyle.setText(s)
        syncKitty()
        // paper is opaque; glass starts see-through, the slider still sets how much
        if (s === "paper") setOpacity(1, true)
        else if (opacityLevel > 0.9) setOpacity(0.6, true)
    }
    function syncKitty() {
        Quickshell.execDetached(["hyprctl", "eval", "hl.window_rule({ name = \"kitty-style\", match = { class = \"^kitty$\" }, "
            + "opacity = \"" + (glass ? "1.0" : "1.0 override 1.0 override") + "\" })"])
    }
    FileView {
        id: savedStyle
        path: root.styleFile
        printErrors: false
        onLoaded: root.style = text().trim() === "glass" ? "glass" : "paper"
    }

    // ---- color swatch: while one is picked (hypr/wallpaper.sh --swatch), the palette comes from its
    // color(s) whatever the wallpaper is, so previewing a wallpaper shows nothing new ----
    JsonFile {
        id: swatchState
        path: Quickshell.env("HOME") + "/.cache/wal-swatch.json"
        watch: true
    }
    readonly property var swatch: swatchState.value.swatch ?? []
    readonly property string harmony: swatchState.value.harmony ?? "analogous"
    readonly property string wallpaper: realColors?.wallpaper ?? ""   // the applied wallpaper

    // A black, grey or white plain wallpaper (hypr/wallpaper.sh --plain, without a swatch) themes the
    // shell in the neutral palette (see `live` below) closest to its lightness, whatever the mode.
    readonly property string plainNeutral: {
        const m = /\/wallpapers\/plain\/([0-9A-F]{6})\.png$/.exec(wallpaper)
        if (!m || swatch.length) return ""
        const c = Qt.color("#" + m[1])
        if (c.hslSaturation > 0.12) return ""
        return c.hslLightness < 0.3 ? "dark" : c.hslLightness > 0.7 ? "light" : "normal"
    }

    // ---- live wallpaper: blue-tinted white, grey and black instead of the wallpaper's colors ----
    // While mpvpaper is running there is no single wallpaper to take colors from, so the theme goes
    // neutral (still darker or lighter by mode). Checked once at startup, and again whenever
    // hypr/mpvpaper.sh starts or ends a live wallpaper (`qs ipc call theme checkLive`).
    property bool live: false
    function checkLive() { liveCheck.running = true }
    Component.onCompleted: checkLive()
    Process {
        id: liveCheck
        command: ["pgrep", "-x", "mpvpaper"]
        onExited: code => {
            const running = code === 0
            if (running === root.live) return
            root.live = running
            root.applyTheme()
        }
    }
    readonly property var neutral: ({
        dark: { bar: ["#0e1118", "#1b2230"], ink: "#e2e8f2", textOnInk: "#0e1118", hover: "#cfe0ff", dark: "#e8edf6",
                card: "#232a36", accent: "#5f7088", accent2: "#a9b6c9", accent3: "#414c5e",
                series: ["#dfe6f1", "#aebbd0", "#8394ad", "#c7d2e3", "#95a5be", "#b8c4d8"] },
        normal: { bar: ["#34404f", "#566478"], ink: "#eef2f8", textOnInk: "#161c26", hover: "#ffffff", dark: "#131822",
                  card: "#ccd4e0", accent: "#7b8ca5", accent2: "#c6d0df", accent3: "#6c7b92",
                  series: ["#26303f", "#4d5b70", "#71829b", "#39465a", "#5d6d85", "#8496ae"] },
        light: { bar: ["#eef3fa", "#9fb0c8"], ink: "#18202c", textOnInk: "#f3f6fb", hover: "#0a1a33", dark: "#18202c",
                 card: "#f4f7fc", accent: "#8fa2bd", accent2: "#4f5f78", accent3: "#bac6d8",
                 series: ["#26303f", "#4d5b70", "#71829b", "#39465a", "#5d6d85", "#8496ae"] }
    })

    // The normal palette (what the wal files or a previewed scheme say) and the bar ends it came with;
    // everything shown is derived from them and the mode.
    property var baseValue: null
    property var baseBar: null
    function setColors(value, bar) {
        baseValue = value
        if (bar) baseBar = bar
        applyTheme()
    }
    function applyTheme() {
        if (live || plainNeutral) {
            const n = neutral[live ? mode : plainNeutral]
            accent = n.accent; accent2 = n.accent2; accent3 = n.accent3
            ink = n.ink; textOnInk = n.textOnInk; hover = n.hover; dark = n.dark; card = alpha(n.card)
            series = n.series
            barStart = alpha(n.bar[0]); barEnd = alpha(n.bar[1])
            return
        }
        const c = baseValue && baseValue.colors
        if (!c) return
        const bg = baseValue.special.background
        accent = c.color1
        accent2 = c.color2
        accent3 = c.color3
        ink = mode === "light" ? bg : c.color7
        textOnInk = mode === "light" ? "#f1f3f8" : bg
        hover = mode === "light" ? darken(Qt.color(c.color9), 0.45) : c.color9
        dark = mode === "dark" ? "#e8ebf2" : bg
        card = alpha(mode === "dark" ? "#2b303b" : mode === "light" ? "#f1f3f8" : "#c3cadb")
        // darkened accents read well on the pale cards; on the dark ones the plain colors do
        series = [1, 2, 3, 4, 5, 6].map(i => mode === "dark" ? Qt.color(c["color" + i]) : darken(Qt.color(c["color" + i]), 0.4))
        if (baseBar) { barStart = alpha(tone(baseBar[0])); barEnd = alpha(tone(baseBar[1])) }
    }

    // ---- wallpaper preview: show another wallpaper's palette without applying it ----
    // The real palette (the wal files) keeps being tracked underneath, so ending the preview
    // returns to it. Applying the wallpaper keeps the preview showing until the wal files are the
    // applied wallpaper's (so the colors don't flash back to the old ones), then switches at once.
    // Scheme files are read on every preview (they are small), so an edited palette shows right away.
    property bool previewing: false
    property bool committing: false
    property string committed           // the wallpaper being applied
    property var realColors: null
    property string wanted            // the scheme path of the latest preview request
    // the bar's gradient ends: the same dark, saturated colour1/colour2 that scripts/bar-colors.py
    // writes for kitty, computed here so they arrive together with the palette
    function barOf(value) { return [vividDark(value.colors.color1), vividDark(value.colors.color2)] }
    function applyReal() { if (realColors && realColors.colors) setColors(realColors, barOf(realColors)) }
    function preview(wallpaper) {
        if (swatch.length) return
        const path = Quickshell.env("HOME") + "/.config/wal/wallpaper-schemes/" + wallpaper.split("/").pop() + ".json"
        previewing = true
        wanted = path
        if (scheme.path === path) scheme.reload()
        else scheme.path = path
    }
    function showScheme(value) {
        if (!previewing) return
        setColors(value, barOf(value))
    }
    function endPreview() {
        if (committing) return
        previewing = false
        applyReal()
    }
    function commitPreview(wallpaper) {
        if (!previewing) return
        committing = true
        committed = wallpaper
        settle.restart()
    }
    function settled() { settle.stop(); committing = false; previewing = false; applyReal() }
    Timer {   // in case the wal files never become the applied wallpaper's
        id: settle
        interval: 6000
        onTriggered: root.settled()
    }
    FileView {
        id: scheme
        printErrors: false
        onLoaded: {
            try {
                const v = JSON.parse(scheme.text())
                if (scheme.path === root.wanted) root.showScheme(v)
            } catch (e) {}
        }
        onLoadFailed: root.endPreview()   // no palette for this wallpaper yet: show the current one
    }

    // the wal files are watched: a new wallpaper's colors arrive as soon as they are written
    JsonFile {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watch: true
        onValueChanged: {
            root.realColors = value
            if (root.committing && value.wallpaper === root.committed) root.settled()
            else if (!root.previewing) root.applyReal()
        }
    }
}
