import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// App launcher that grows out of the top band at the left, drawn by the frame like the calendar.
// Apps come from the desktop entries, always in alphabetical order. Type to filter, arrow keys or the
// mouse to select (hovering selects, a click launches), Enter launches, Escape closes.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int band: 48
    readonly property int side: 10
    readonly property int columns: 4
    readonly property real openW: 1180
    readonly property real openH: Math.min(parent.height - band - side - 40, 1400)
    property real panelW: 0
    property real panelH: 0

    anchors { top: parent.top; left: parent.left; leftMargin: band }
    width: panelW
    height: band + panelH

    // ---- apps ----
    readonly property var allApps: {
        const out = []
        const seen = new Set()   // ~/.local/share/applications/snap links to snapd's dir, so snap apps are listed twice
        for (const e of DesktopEntries.applications.values) {
            const key = e.name + "\0" + e.execString
            if (e.noDisplay || seen.has(key)) continue
            seen.add(key)
            out.push(e)
        }
        out.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
        return out
    }
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var shown: {
        if (query === "") return allApps
        return allApps.filter(e =>
            e.name.toLowerCase().includes(query)
            || (e.genericName || "").toLowerCase().includes(query)
            || (e.comment || "").toLowerCase().includes(query)
            || (e.keywords || []).some(k => k.toLowerCase().includes(query)))
    }
    function launch(entry) {
        if (!entry) return
        entry.execute()
        panel.toggle()
    }
    onOpenChanged: {
        scrollAnim.stop()
        grid.contentY = grid.originY
        if (open) { search.text = ""; grid.currentIndex = 0; search.forceActiveFocus() }
    }
    onShownChanged: grid.currentIndex = 0

    // Eases out when opening and eases in when closing, like the other panels.
    states: State {
        name: "open"
        when: panel.open
        PropertyChanges { target: panel; panelW: panel.openW; panelH: panel.openH }
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

    Item {
        id: content
        anchors { fill: parent; margins: 16; topMargin: panel.band + 16; leftMargin: 0 }   // the frame's left band is already 48px of space on that side
        clip: true
        opacity: panel.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: panel.open ? 140 : 0 }
                NumberAnimation { duration: panel.open ? 260 : 100 }
            }
        }

        // ---- search ----
        Rectangle {
            id: searchBox
            width: parent.width
            height: 58
            radius: 10
            color: panel.theme.card
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#55000000"
                shadowBlur: 0.45
                shadowVerticalOffset: 3
            }
            TextInput {
                id: search
                anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                verticalAlignment: TextInput.AlignVCenter
                color: panel.theme.dark
                selectionColor: panel.theme.accent
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 20
                clip: true
                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text === ""
                    text: "Search"
                    color: Qt.rgba(panel.theme.dark.r, panel.theme.dark.g, panel.theme.dark.b, 0.45)
                    font: search.font
                }
                Keys.onEscapePressed: panel.toggle()
                Keys.onReturnPressed: panel.launch(panel.shown[grid.currentIndex])
                Keys.onEnterPressed: panel.launch(panel.shown[grid.currentIndex])
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onLeftPressed: event => { if (cursorPosition === 0) grid.moveCurrentIndexLeft(); else event.accepted = false }
                Keys.onRightPressed: event => { if (cursorPosition === text.length) grid.moveCurrentIndexRight(); else event.accepted = false }
            }
        }

        // ---- the apps ----
        GridView {
            id: grid
            anchors { top: searchBox.bottom; topMargin: 18; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true
            cellWidth: width / panel.columns
            cellHeight: 88
            model: panel.shown
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            onContentYChanged: if (contentY < originY) contentY = originY   // never show empty space above the first row
            interactive: false   // the WheelHandler below does all scrolling; Flickable's own wheel flick fought it and overshot

            // Mouse wheel: the default step is tiny. Each notch scrolls ~3.5 rows, eased over 160ms.
            NumberAnimation { id: scrollAnim; target: grid; property: "contentY"; duration: 160; easing.type: Easing.OutCubic }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const step = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 2 : event.angleDelta.y * 2.6
                    const max = Math.max(0, grid.contentHeight - grid.height)
                    const from = scrollAnim.running ? scrollAnim.to : grid.contentY
                    scrollAnim.stop()
                    scrollAnim.to = Math.max(0, Math.min(max, from - step))
                    scrollAnim.from = grid.contentY
                    scrollAnim.start()
                }
            }
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                readonly property bool current: GridView.isCurrentItem

                Rectangle {   // the card
                    anchors { fill: parent; margins: 6 }
                    radius: 10
                    color: panel.theme.card
                    opacity: cell.current ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
                Item {   // everything but the base card rises 6px and shifts 4px right when selected
                    width: parent.width; height: parent.height
                    x: cell.current ? 4 : 0
                    y: cell.current ? -6 : 0
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Rectangle {   // selection: accent color and raised, fades in/out as the selection moves
                        anchors { fill: parent; margins: 6 }
                        radius: 10
                        color: panel.theme.accent
                        opacity: cell.current ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#99000000"
                            shadowBlur: 0.6
                            shadowVerticalOffset: 4
                        }
                    }
                    Rectangle {   // icon tile, recessed into the card
                        id: tile
                        x: 20; anchors.verticalCenter: parent.verticalCenter
                        width: 52; height: 52; radius: 12
                        color: "transparent"
                        // Flat recess, not a bowl: only the edges are shaded (a soft dark band under the top
                        // edge, a faint light line along the bottom); the middle is the card's own color.
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.16) }
                            GradientStop { position: 0.10; color: Qt.rgba(0, 0, 0, 0.03) }
                            GradientStop { position: 0.2; color: "transparent" }
                            GradientStop { position: 0.84; color: "transparent" }
                            GradientStop { position: 0.95; color: Qt.rgba(0, 0, 0, 0.06) }   // subtle shadow inside the bottom edge
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.16) }
                        }
                        Rectangle {   // subtle shadow inside the left and right edges
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.07) }
                                GradientStop { position: 0.12; color: "transparent" }
                                GradientStop { position: 0.88; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.07) }
                            }
                        }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 32
                            source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                        }
                    }
                    Text {
                        anchors { left: tile.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        text: cell.modelData.name
                        elide: Text.ElideRight
                        color: panel.theme.dark
                        font.family: "CodeNewRoman Nerd Font Mono"
                        font.pixelSize: 17
                        font.bold: cell.current
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: grid.currentIndex = cell.index   // hovering selects
                    onClicked: panel.launch(cell.modelData)
                }
            }
        }
    }
}
