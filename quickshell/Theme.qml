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
    property color barStart: "#742306"     // waybar side-section gradient ends
    property color barEnd: "#1c375f"
    property color card: "#c3cadb"         // fixed pale blue-grey card, as in the sysstats panel
    property var series: ["#e06c75", "#61afef", "#98c379", "#e5c07b", "#c678dd", "#56b6c2"]

    // colors fade into each other (a wallpaper preview, or a new wallpaper being applied)
    Behavior on accent { ColorAnimation { duration: 250 } }
    Behavior on ink { ColorAnimation { duration: 250 } }
    Behavior on hover { ColorAnimation { duration: 250 } }
    Behavior on accent2 { ColorAnimation { duration: 250 } }
    Behavior on accent3 { ColorAnimation { duration: 250 } }
    Behavior on dark { ColorAnimation { duration: 250 } }
    Behavior on barStart { ColorAnimation { duration: 250 } }
    Behavior on barEnd { ColorAnimation { duration: 250 } }

    function darken(c, t) { return Qt.rgba(c.r * (1 - t), c.g * (1 - t), c.b * (1 - t), 1) }
    // same as the dark, saturated bar ends in scripts/bar-colors.py
    function vividDark(hex) {
        const c = Qt.color(hex)
        return Qt.hsla(c.hslHue, Math.min(0.9, Math.max(c.hslSaturation * 1.3, 0.55)), 0.24, 1)
    }
    function setColors(value, bar) {
        const c = value.colors
        if (!c) return
        accent = c.color1
        ink = c.color7
        hover = c.color9
        accent2 = c.color2
        accent3 = c.color3
        dark = value.special.background
        // darkened accents read well on the pale cards
        series = [1, 2, 3, 4, 5, 6].map(i => darken(Qt.color(c["color" + i]), 0.4))
        if (bar) { barStart = bar[0]; barEnd = bar[1] }
    }

    // ---- wallpaper preview: show another wallpaper's palette without applying it ----
    // The real palette (the wal files) keeps being tracked underneath, so ending the preview
    // returns to it. Applying the wallpaper keeps the preview showing until the wal files have
    // caught up, so the colors don't flash back to the old ones.
    property bool previewing: false
    property bool committing: false
    property var realColors: null
    property var realBar: null
    property var schemes: ({})        // scheme path -> parsed json
    property string wanted            // the scheme path of the latest preview request
    function applyReal() { if (realColors) setColors(realColors, realBar) }
    function preview(wallpaper) {
        const path = Quickshell.env("HOME") + "/.config/wal/wallpaper-schemes/" + wallpaper.split("/").pop() + ".json"
        previewing = true
        wanted = path
        if (schemes[path]) showScheme(schemes[path])
        else if (scheme.path === path) endPreview()   // already tried: it has no palette
        else scheme.path = path
    }
    function showScheme(value) {
        if (!previewing) return
        setColors(value, [vividDark(value.colors.color1), vividDark(value.colors.color2)])
    }
    function endPreview() {
        if (committing) return
        previewing = false
        applyReal()
    }
    function commitPreview() {
        if (!previewing) return
        committing = true
        settle.restart()
    }
    Timer {
        id: settle
        interval: 4000
        onTriggered: { root.committing = false; root.previewing = false; root.applyReal() }
    }
    FileView {
        id: scheme
        printErrors: false
        onLoaded: {
            try {
                const v = JSON.parse(scheme.text())
                root.schemes[scheme.path] = v
                if (scheme.path === root.wanted) root.showScheme(v)
            } catch (e) {}
        }
        onLoadFailed: root.endPreview()   // no palette for this wallpaper yet: show the current one
    }

    JsonFile {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        interval: 2000
        onValueChanged: {
            root.realColors = value
            if (!root.previewing) root.applyReal()
        }
    }
    FileView {
        id: barCss
        path: Quickshell.env("HOME") + "/.cache/wal/colors-waybar-bar.css"
        onLoaded: {
            const start = /bar_start (#\w{6})/.exec(barCss.text())
            const end = /bar_end (#\w{6})/.exec(barCss.text())
            if (!start || !end) return
            root.realBar = [start[1], end[1]]
            if (!root.previewing) { root.barStart = start[1]; root.barEnd = end[1] }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: barCss.reload()
    }
}
