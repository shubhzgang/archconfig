import QtQuick
import Quickshell

// The stats numbers in the top band, at the right, as in waybar (CPU, RAM, network, GPUs). They live
// on the thin bar surface (see shell.qml) so their once-a-second updates don't redraw the whole
// screen-sized shell surface. Clicking them toggles the stats panel; they stay put while it is open.
Item {
    id: root
    required property var theme
    signal toggle()

    readonly property int band: 48         // the frame's top band (Frame.qml)
    readonly property int side: 10         // its right band
    readonly property int collapsedW: 900  // the stats corner's width when closed (StatsCorner.qml)
    readonly property int rowH: 39

    // centered in the closed stats corner; when the numbers get wider than that (a fast network
    // speed) they grow to the left, never closer than 24px to the frame's right band
    anchors { top: parent.top; topMargin: (band - rowH) / 2
              right: parent.right; rightMargin: side + Math.max((collapsedW - width) / 2, 24) }
    width: numbers.width
    height: rowH

    readonly property string rundir: Quickshell.env("XDG_RUNTIME_DIR") + "/sysstats/"
    JsonFile { id: cpuFile; path: root.rundir + "cpu.json" }
    JsonFile { id: memFile; path: root.rundir + "mem.json" }
    JsonFile { id: netFile; path: root.rundir + "net.json" }
    JsonFile { id: gpuFile; path: root.rundir + "gpu.json" }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }

    Row {
        id: numbers
        height: root.rowH
        spacing: 0

        Repeater {
            model: [cpuFile, memFile, netFile, gpuFile]
            delegate: Item {
                required property var modelData
                required property int index
                width: label.implicitWidth + 36
                height: root.rowH
                Rectangle {   // thin divider between modules
                    visible: index > 0
                    width: 1; height: parent.height - 12; anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(root.theme.ink.r, root.theme.ink.g, root.theme.ink.b, 0.2)
                }
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.value.text || ""
                    color: root.theme.ink
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 15
                }
            }
        }
    }
}
