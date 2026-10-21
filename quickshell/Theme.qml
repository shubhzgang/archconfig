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

    function darken(c, t) { return Qt.rgba(c.r * (1 - t), c.g * (1 - t), c.b * (1 - t), 1) }

    JsonFile {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        interval: 2000
        onValueChanged: {
            const c = value.colors
            if (!c) return
            root.accent = c.color1
            root.ink = c.color7
            root.hover = c.color9
            root.accent2 = c.color2
            root.accent3 = c.color3
            root.dark = value.special.background
            // darkened accents read well on the pale cards
            root.series = [1, 2, 3, 4, 5, 6].map(i => root.darken(Qt.color(c["color" + i]), 0.4))
        }
    }
    FileView {
        id: barCss
        path: Quickshell.env("HOME") + "/.cache/wal/colors-waybar-bar.css"
        onLoaded: {
            const start = /bar_start (#\w{6})/.exec(barCss.text())
            const end = /bar_end (#\w{6})/.exec(barCss.text())
            if (start) root.barStart = start[1]
            if (end) root.barEnd = end[1]
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
