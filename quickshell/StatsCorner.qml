import QtQuick
import Quickshell

// Top-right corner: the stats numbers (collapsed, where waybar's right section is) that grow into
// the full stats panel in the same corner when clicked.
Rectangle {
    id: corner
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int collapsedW: 900
    readonly property int collapsedH: 46
    readonly property var st: stateFile.value
    readonly property int points: st.points || 120

    anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 10 }
    width: open ? 1000 : collapsedW
    // fit the cards: the same 16px of space at the bottom as at the top
    height: open ? Math.min(parent.height - 20, cards.implicitHeight + 32) : collapsedH
    radius: 10
    border.width: 2
    border.color: theme.accent
    clip: true
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: theme.barStart }
        GradientStop { position: 1; color: theme.barEnd }
    }

    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    function fmtBytes(n) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let i = 0
        while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
        return (i === 0 ? n.toFixed(0) : n.toFixed(1)) + " " + units[i]
    }
    function niceCeiling(v) {
        if (v <= 0) return 1
        const mag = Math.pow(10, Math.floor(Math.log10(v)))
        for (const m of [1, 2, 5, 10]) if (v <= m * mag) return m * mag
        return v
    }
    function last(a) { return a && a.length ? a[a.length - 1] : 0 }

    readonly property string rundir: Quickshell.env("XDG_RUNTIME_DIR") + "/sysstats/"
    JsonFile { id: stateFile; path: corner.rundir + "state.json" }
    JsonFile { id: cpuFile; path: corner.rundir + "cpu.json" }
    JsonFile { id: memFile; path: corner.rundir + "mem.json" }
    JsonFile { id: netFile; path: corner.rundir + "net.json" }
    JsonFile { id: gpuFile; path: corner.rundir + "gpu.json" }

    // ---- collapsed: the numbers, as in waybar ----
    Row {
        id: numbers
        height: corner.collapsedH
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0
        opacity: corner.open ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Repeater {
            model: [cpuFile, memFile, netFile, gpuFile]
            delegate: Item {
                required property var modelData
                required property int index
                width: label.implicitWidth + 36
                height: corner.collapsedH
                Rectangle {   // thin divider between modules
                    visible: index > 0
                    width: 1; height: parent.height - 12; anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(corner.theme.ink.r, corner.theme.ink.g, corner.theme.ink.b, 0.2)
                }
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.value.text || ""
                    color: corner.theme.ink
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 15
                }
            }
        }
    }

    // ---- expanded: the panel ----
    Item {
        id: panel
        anchors { fill: parent; margins: 16 }
        opacity: corner.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: corner.open ? 260 : 120 } }

        Flickable {
            anchors.fill: parent
            contentHeight: cards.implicitHeight
            clip: true
            Column {
                id: cards
                width: parent.width
                spacing: 16

                Card {
                    theme: corner.theme; width: parent.width
                    GraphBlock {
                        theme: corner.theme; width: parent.width; points: corner.points
                        title: "CPU"
                        value: corner.last(corner.st.cpu).toFixed(0) + "%   " + ((corner.st.freq || 0) / 1000).toFixed(1) + " GHz"
                        ymax: 100; maxLabel: "100%"
                        series: [{ values: corner.st.cpu || [], color: corner.theme.series[3] }]
                    }
                }
                Card {
                    theme: corner.theme; width: parent.width
                    Repeater {
                        model: [
                            { name: "used", key: "mem_used", color: 1 },
                            { name: "cached", key: "mem_cached", color: 2 },
                            { name: "free", key: "mem_free", color: -1 }
                        ]
                        delegate: GraphBlock {
                            required property var modelData
                            theme: corner.theme; width: parent.width; points: corner.points
                            title: "RAM " + modelData.name
                            value: corner.fmtBytes(corner.last(corner.st[modelData.key]))
                            ymax: corner.st.mem_total || 1
                            maxLabel: corner.fmtBytes(corner.st.mem_total || 0)
                            series: [{ values: corner.st[modelData.key] || [],
                                       color: modelData.color < 0 ? corner.theme.dark : corner.theme.series[modelData.color] }]
                        }
                    }
                }
                Card {
                    theme: corner.theme; width: parent.width
                    GraphBlock {
                        theme: corner.theme; width: parent.width; points: corner.points
                        mirrored: true
                        title: "Network"
                        value: "down " + corner.fmtBytes(corner.last(corner.st.net_down)) + "/s   up "
                               + corner.fmtBytes(corner.last(corner.st.net_up)) + "/s"
                        // each direction has its own scale (floor 100 KiB/s), labeled at its edge
                        ymax: corner.niceCeiling(Math.max(102400, ...(corner.st.net_down || [])) * 1.1)
                        ymax2: corner.niceCeiling(Math.max(102400, ...(corner.st.net_up || [])) * 1.1)
                        maxLabel: corner.fmtBytes(ymax) + "/s"
                        maxLabel2: corner.fmtBytes(ymax2) + "/s"
                        series: [{ values: corner.st.net_down || [], color: corner.theme.series[3] },
                                 { values: corner.st.net_up || [], color: corner.theme.series[4] }]
                    }
                }
                Repeater {
                    model: Object.keys(corner.st.gpus || {}).sort()
                    delegate: Card {
                        required property string modelData
                        readonly property var g: corner.st.gpus[modelData]
                        theme: corner.theme; width: parent.width
                        GraphBlock {
                            theme: corner.theme; width: parent.width; points: corner.points
                            title: g.name + " usage"
                            value: corner.last(g.util).toFixed(0) + "%"
                            ymax: 100; maxLabel: "100%"
                            series: [{ values: g.util || [], color: corner.theme.series[5] }]
                        }
                        GraphBlock {
                            theme: corner.theme; width: parent.width; points: corner.points
                            title: g.name + " memory"
                            value: corner.fmtBytes(corner.last(g.mem)) + " / " + corner.fmtBytes(g.mem_total)
                            ymax: g.mem_total || 1; maxLabel: corner.fmtBytes(g.mem_total || 0)
                            series: [{ values: g.mem || [], color: corner.theme.series[1] }]
                        }
                    }
                }
            }
        }
    }

    // click anywhere on it to morph between the numbers and the panel (Escape and a click
    // outside also close it, see shell.qml). Declared last so it sits above the cards; future
    // buttons inside the panel would need their own MouseArea above this one.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: corner.toggle()
    }
}
