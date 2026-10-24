import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// A searchable list that slides out of the bottom of the frame's left band, drawn by the frame like
// the other panels. The users (ClipboardPanel, LiveWallpaperPanel) fill `entries` ({ text, ... }) when
// `opening` fires and act on `picked`. Type to filter, Up/Down or the mouse to select (hovering
// selects, a click picks), Enter picks the selected entry and closes (unless it has `keepOpen`),
// Escape closes. An entry can have a `thumb` (an image path), and with `removable` set on the panel
// and on the entry, a trash button (or Shift+Delete) asks to remove it.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int band: 48      // the frame's left band (Frame.qml)
    readonly property int side: 10      // its bottom band
    property real openW: 880
    property int rowH: 76                // height of an entry
    property int thumbW: 96              // width of an entry's thumbnail (16:9)
    property int fontSize: 15
    property real maxH: 960
    property string placeholder: "Search"
    property bool removable: false
    signal removeRequested(var entry)
    function clearSearch() { search.text = "" }
    property int fitRows: 0              // > 0: just tall enough for this many rows (else as tall as the screen allows)
    readonly property real openH: Math.min(maxH, parent.height - band - side - 160,
                                           fitRows > 0 ? 32 + 58 + 14 + fitRows * rowH + 6 : maxH)
    property real panelW: 0

    // in the bottom-left corner of the free area; only the width animates
    anchors { left: parent.left; leftMargin: band; bottom: parent.bottom; bottomMargin: side }
    width: panelW
    height: openH
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }   // the list grew or shrank
    clip: true

    // ---- entries ----
    property var entries: []         // { text: what is shown, ... }
    property var extraEntries: []    // shown above the matches whatever is typed (e.g. "play this link")
    signal opening()                 // the panel is opening: refresh `entries`
    signal picked(var entry)
    readonly property string typed: search.text.trim()
    readonly property string query: typed.toLowerCase()
    readonly property var shown: extraEntries.concat(query === "" ? entries : entries.filter(e => e.text.toLowerCase().includes(query)))
    function choose(entry) {
        if (!entry) return
        picked(entry)
        if (!entry.keepOpen) panel.toggle()
    }
    onOpenChanged: {
        if (!open) return
        search.text = ""
        list.currentIndex = 0
        scrollAnim.stop()
        list.positionViewAtBeginning()
        opening()
        search.forceActiveFocus()
    }
    onShownChanged: list.currentIndex = 0

    // The panel slides out of the band with an ease-out, and back with an ease-in. The content
    // fades in once it has (nearly) finished, and is the first thing to go when closing.
    // (States + transitions rather than Behaviors, see StatsCorner.qml.)
    states: State {
        name: "open"
        when: panel.open
        PropertyChanges { target: panel; panelW: panel.openW }
        PropertyChanges { target: content; opacity: 1 }
    }
    transitions: [
        Transition {
            from: ""; to: "open"
            ParallelAnimation {
                NumberAnimation { target: panel; property: "panelW"; duration: 520; easing.type: Easing.OutQuint }
                SequentialAnimation {
                    PauseAnimation { duration: 420 }
                    NumberAnimation { target: content; property: "opacity"; duration: 160 }
                }
            }
        },
        Transition {
            from: "open"; to: ""
            SequentialAnimation {
                NumberAnimation { target: content; property: "opacity"; duration: 90 }
                NumberAnimation { target: panel; property: "panelW"; duration: 400; easing.type: Easing.InQuint }
            }
        }
    ]

    Item {
        id: content
        x: 16; y: 16
        width: panel.openW - 32      // fixed, so nothing reflows while the panel slides out
        height: panel.openH - 32
        opacity: 0
        visible: opacity > 0

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
                    text: panel.placeholder
                    color: Qt.rgba(panel.theme.dark.r, panel.theme.dark.g, panel.theme.dark.b, 0.45)
                    font: search.font
                }
                Keys.onEscapePressed: panel.toggle()
                Keys.onPressed: event => {
                    const entry = panel.shown[list.currentIndex]
                    if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier) && panel.removable && entry && entry.removable) {
                        panel.removeRequested(entry)
                        event.accepted = true
                    }
                }
                Keys.onReturnPressed: panel.choose(panel.shown[list.currentIndex])
                Keys.onEnterPressed: panel.choose(panel.shown[list.currentIndex])
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
            }
        }

        ListView {
            id: list
            anchors { top: searchBox.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true
            model: panel.shown
            boundsBehavior: Flickable.StopAtBounds
            interactive: false   // the WheelHandler below does all scrolling (the default wheel step is tiny)

            // Mouse wheel: each notch scrolls ~2.5 rows, eased over 160ms.
            NumberAnimation { id: scrollAnim; target: list; property: "contentY"; duration: 160; easing.type: Easing.OutCubic }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const step = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 1.3 : event.angleDelta.y * 1.7
                    const max = Math.max(0, list.contentHeight - list.height)
                    const from = scrollAnim.running ? scrollAnim.to : list.contentY
                    scrollAnim.stop()
                    scrollAnim.to = Math.max(0, Math.min(max, from - step))
                    scrollAnim.from = list.contentY
                    scrollAnim.start()
                }
            }
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: panel.rowH
                readonly property bool current: ListView.isCurrentItem
                // the selected entry is picked up, as in the launcher: it rises 6px and shifts 4px right,
                // with a deeper shadow
                property real lift: current ? 1 : 0
                Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors { fill: parent; margins: 6 }
                    transform: Translate { x: 4 * row.lift; y: -6 * row.lift }
                    radius: 10
                    color: row.current ? panel.theme.accent : panel.theme.card
                    Behavior on color { ColorAnimation { duration: 150 } }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.33 + 0.27 * row.lift)
                        shadowBlur: 0.45 + 0.15 * row.lift
                        shadowVerticalOffset: 3 + row.lift
                    }
                    ClippingRectangle {   // the entry's thumbnail, if it has one
                        id: thumb
                        visible: row.modelData.thumb !== undefined
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: panel.thumbW; height: panel.thumbW * 9 / 16
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.12)
                        Image {
                            anchors.fill: parent
                            source: row.modelData.thumb ? "file://" + row.modelData.thumb : ""
                            sourceSize: Qt.size(panel.thumbW * 2, panel.thumbW * 9 / 8)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Text {
                        anchors { fill: parent; rightMargin: trash.visible ? 60 : 16; topMargin: 6; bottomMargin: 6
                                  leftMargin: thumb.visible ? thumb.x + thumb.width + 14 : 16 }
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData.text
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: panel.theme.dark
                        font.family: "CodeNewRoman Nerd Font Mono"
                        font.pixelSize: panel.fontSize
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: list.currentIndex = row.index   // hovering selects
                    onClicked: panel.choose(row.modelData)
                }
                Item {   // remove button, on the selected row
                    id: trash
                    visible: row.current && panel.removable && !!row.modelData.removable
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    transform: Translate { x: 4 * row.lift; y: -6 * row.lift }   // (on the picked-up entry)
                    width: 40; height: 40
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF0A7A)   // trash can
                        color: trashArea.containsMouse ? "white" : panel.theme.dark
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 22
                    }
                    MouseArea {
                        id: trashArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.removeRequested(row.modelData)
                    }
                }
            }
        }
    }
}
