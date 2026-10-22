import QtQuick
import Quickshell
import Quickshell.Io

// Top-right corner: the stats numbers (collapsed, where waybar's right section is) that grow into
// the full stats panel in the same corner when clicked.
Item {
    id: corner
    required property var theme
    property bool open: false
    signal toggle()

    // Geometry shared with Frame.qml: the numbers live in the top band; the panel hangs from the
    // band at the right and is drawn by the frame itself (its outline flows into the frame).
    readonly property int band: 48
    readonly property int side: 10         // the frame's side bands (Frame.qml)
    readonly property int collapsedW: 900
    readonly property int collapsedH: 39   // height of the numbers row
    readonly property var st: stateFile.value
    readonly property int points: st.points || 120
    readonly property real interval: st.interval || 1

    // Sampling settings live in hypr/sysstats.json; sysstatsd.py applies a change at once and
    // restarts the graphs.
    FileView {
        id: settings
        path: Quickshell.env("HOME") + "/.config/hypr/sysstats.json"
        atomicWrites: true
        printErrors: true
    }
    function setSampling(interval, points) {
        settings.setText(JSON.stringify({ interval: interval, points: points }, null, 2) + "\n")
    }
    function span(seconds) {
        const m = Math.floor(seconds / 60), s = Math.round(seconds % 60)
        return m ? "last " + m + "m " + (s < 10 ? "0" : "") + s + "s" : "last " + s + "s"
    }

    // size of the panel below the band; expanded: fit the cards, same 16px space at top and bottom
    readonly property real openW: 1000
    readonly property int controlsH: 34    // the sampling controls row above the cards
    readonly property real openH: Math.min(parent.height - band - side - 20, controlsH + 12 + cards.implicitHeight + 32)
    property real panelW: collapsedW
    property real panelH: 0
    anchors { top: parent.top; right: parent.right; rightMargin: side }
    width: panelW
    height: band + panelH

    // Opening decelerates as it nears full size; closing starts slow and speeds up. No overshoot.
    // (States + transitions rather than a Behavior: the easing is picked by direction, whereas a
    // Behavior read `open` before it had updated and used the wrong curve.)
    states: State {
        name: "open"
        when: corner.open
        PropertyChanges { target: corner; panelW: corner.openW; panelH: corner.openH }
    }
    transitions: [
        Transition {
            from: ""; to: "open"
            NumberAnimation { property: "panelW"; duration: 520; easing.type: Easing.OutQuint }
            NumberAnimation { property: "panelH"; duration: 620; easing.type: Easing.OutQuint }
        },
        Transition {
            from: "open"; to: ""
            NumberAnimation { property: "panelW"; duration: 430; easing.type: Easing.InQuint }
            NumberAnimation { property: "panelH"; duration: 500; easing.type: Easing.InQuint }
        }
    ]

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

    // click anywhere on it to morph between the numbers and the panel (Escape and a click
    // outside also close it, see shell.qml). Declared before the panel so the buttons inside
    // it (above) take their own clicks.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: corner.toggle()
    }

    // ---- the numbers, as in waybar; they stay when the panel is open ----
    Row {
        id: numbers
        height: corner.collapsedH
        // stays where it is on screen (centered in the collapsed width) while the panel grows below it
        anchors { top: parent.top; topMargin: (corner.band - corner.collapsedH) / 2
                  right: parent.right; rightMargin: (corner.collapsedW - width) / 2 }
        spacing: 0

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
        anchors { fill: parent; margins: 16; topMargin: corner.band + 16 }
        clip: true
        opacity: corner.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {   // content fades in once the shape has (nearly) finished growing
            SequentialAnimation {
                PauseAnimation { duration: corner.open ? 300 : 0 }
                NumberAnimation { duration: corner.open ? 150 : 100 }
            }
        }

        // ---- the sampling controls, under the numbers ----
        Item {
            id: controlsBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: corner.controlsH

            Row {
                id: controls
            anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                Text {
                    text: "every"
                    color: corner.theme.ink
                    font.family: "CodeNewRoman Nerd Font Mono"; font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 6
                }
                Repeater {
                    model: [1, 2, 3, 5, 10]
                    delegate: Chip {
                        required property int modelData
                        theme: corner.theme
                        anchors.verticalCenter: parent.verticalCenter
                        label: modelData + "s"
                        selected: corner.interval === modelData
                        onClicked: corner.setSampling(modelData, corner.points)
                    }
                }
                Item { width: 18; height: 1 }
                Text {
                    text: "points"
                    color: corner.theme.ink
                    font.family: "CodeNewRoman Nerd Font Mono"; font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 6
                }
                Repeater {
                    model: [30, 60, 120, 240, 360, 480, 600]
                    delegate: Chip {
                        required property int modelData
                        theme: corner.theme
                        anchors.verticalCenter: parent.verticalCenter
                        label: String(modelData)
                        selected: corner.points === modelData
                        onClicked: corner.setSampling(corner.interval, modelData)
                    }
                }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: corner.span(corner.interval * corner.points)
                color: corner.theme.ink
                font.family: "CodeNewRoman Nerd Font Mono"; font.pixelSize: 16
            }
        }

        Flickable {
            anchors { top: controlsBar.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
            interactive: contentHeight > height   // only scrolls if the cards outgrow the screen
            contentHeight: cards.implicitHeight
            clip: true
            Column {
                id: cards
                width: corner.openW - 32   // fixed, so the graphs don't resize while the panel grows
                spacing: 16

                Card {
                    theme: corner.theme; width: parent.width
                    GraphBlock {
                        theme: corner.theme; width: parent.width; points: corner.points; interval: corner.interval
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
                            theme: corner.theme; width: parent.width; points: corner.points; interval: corner.interval
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
                        theme: corner.theme; width: parent.width; points: corner.points; interval: corner.interval
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
                            theme: corner.theme; width: parent.width; points: corner.points; interval: corner.interval
                            title: g.name + " usage"
                            value: corner.last(g.util).toFixed(0) + "%"
                            ymax: 100; maxLabel: "100%"
                            series: [{ values: g.util || [], color: corner.theme.series[5] }]
                        }
                        GraphBlock {
                            theme: corner.theme; width: parent.width; points: corner.points; interval: corner.interval
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
}
