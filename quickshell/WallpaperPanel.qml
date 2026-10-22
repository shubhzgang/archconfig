import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Wallpaper picker that grows up out of the bottom band, drawn by the frame like the other panels.
// A carousel of five equal thumbnails with a smaller one peeking in at each end. Left/Right (or the
// wheel) move the selection across the five; the carousel only slides, by one, when the selection
// steps onto a peeking one. It wraps around at both ends (after the last wallpaper comes the first).
// It opens on the current wallpaper. Enter or a click on the selected
// one applies it (hypr/wallpaper.sh), a click on another one selects it, Escape closes.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int side: 10
    readonly property string dir: Quickshell.env("HOME") + "/wallpapers/walls"

    // carousel geometry: a thumbnail at distance k from the middle of the five is shown at scale[k]
    // and opacity fade[k]; positions in between are interpolated, so the carousel moves continuously
    readonly property real thumbW: 320
    readonly property real thumbH: 180
    readonly property int gap: 20
    readonly property var scales: [1, 1, 1, 0.72, 0.5]
    readonly property var fade: [1, 1, 1, 1, 0]
    readonly property var centers: {   // center-to-center offset of each slot from the middle one
        const c = [0]
        for (let k = 1; k < scales.length; k++)
            c.push(c[k - 1] + thumbW * (scales[k - 1] + scales[k]) / 2 + gap)
        return c
    }
    function lerp(arr, d) {   // arr[|d|], interpolated between slots
        const a = Math.min(Math.abs(d), arr.length - 1)
        const i = Math.min(Math.floor(a), arr.length - 2)
        return arr[i] + (arr[i + 1] - arr[i]) * (a - i)
    }

    readonly property int pad: 40   // room around the thumbnails for their shadows (the panel clips)
    readonly property real openW: centers[3] * 2 + thumbW * scales[3] + 2 * pad
    readonly property real openH: thumbH + 2 * pad
    readonly property real panelW: openW   // full width from the start: the panel rises, it doesn't expand
    property real panelH: 0

    anchors { bottom: parent.bottom; bottomMargin: side; horizontalCenter: parent.horizontalCenter }
    width: panelW
    height: panelH
    clip: true   // the thumbnails never show outside the fill, even while it is still sinking

    // ---- wallpapers ----
    property var files: []
    // The carousel wraps around: after the last wallpaper comes the first again, and before the
    // first the last. `cursor` and `first` count on without wrapping (so the slide always goes the
    // short way, even across the wrap); `current` is the wallpaper they point at.
    property int cursor: 0      // the selection
    property int first: 0       // the leftmost of the five shown at full size
    readonly property int current: wrap(cursor)   // the selected wallpaper (index into files)
    property real position: 0   // `first`, animated
    property bool snap: false   // jump instead of sliding
    onFirstChanged: position = first
    Behavior on position { enabled: !panel.snap; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    function wrap(i) { const n = files.length; return n ? ((i % n) + n) % n : 0 }
    function offset(d) { const n = files.length; return n ? d - n * Math.round(d / n) : d }   // shortest way round
    function select(c) {   // move the selection to cursor value c
        cursor = c
        if (cursor < first) first = cursor
        else if (cursor > first + 4) first = cursor - 4
        theme.preview(files[current])
    }
    function show(i) {   // select wallpaper i and put it in the middle of the five, without sliding
        snap = true
        cursor = i
        first = i - 2
        position = first
        snap = false
    }

    Process {
        id: lister
        command: ["bash", "-c", "find '" + panel.dir + "' -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \\) | sort"]
        stdout: StdioCollector {
            onStreamFinished: panel.files = text.split("\n").filter(f => f !== "")
        }
    }
    Component.onCompleted: lister.running = true

    // the wallpaper swww is showing now ("... currently displaying: image: /path")
    Process {
        id: now
        command: ["swww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /image: (.+)/.exec(text)
                panel.show(Math.max(0, panel.files.indexOf(m ? m[1].trim() : "")))
            }
        }
    }

    function move(by) { if (files.length) select(cursor + by) }
    function apply(path) {
        if (!path) return
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/wallpaper.sh", path])
        theme.commitPreview(path)
        panel.toggle()
    }
    onOpenChanged: {
        if (open) { keys.forceActiveFocus(); now.running = true }
        else theme.endPreview()   // closed without applying: back to the real colors
    }

    // Rises with an ease-out when opening and sinks with an ease-in when closing, like the other panels.
    states: State {
        name: "open"
        when: panel.open
        PropertyChanges { target: panel; panelH: panel.openH }
    }
    transitions: [
        Transition {
            from: ""; to: "open"
            NumberAnimation { property: "panelH"; duration: 620; easing.type: Easing.OutQuint }
        },
        Transition {
            from: "open"; to: ""
            SequentialAnimation {   // the thumbnails go first, then the shape sinks
                PauseAnimation { duration: 140 }
                NumberAnimation { property: "panelH"; duration: 500; easing.type: Easing.InQuint }
            }
        }
    ]

    Item {
        id: content
        anchors { bottom: parent.bottom; bottomMargin: panel.pad; horizontalCenter: parent.horizontalCenter }
        width: panel.openW - 2 * panel.pad      // fixed, so the thumbnails don't move while the panel grows
        height: panel.openH - 2 * panel.pad
        transformOrigin: Item.Bottom
        opacity: 0
        scale: 0.94
        visible: opacity > 0
        // The thumbnails pop in (fade and a small grow) once the shape has finished rising, and
        // are the first thing to go when closing. (States + transitions rather than Behaviors: a
        // Behavior read `open` before it had updated, so the delays were picked for the wrong direction.)
        states: State {
            name: "shown"
            when: panel.open
            PropertyChanges { target: content; opacity: 1; scale: 1 }
        }
        transitions: [
            Transition {
                from: ""; to: "shown"
                SequentialAnimation {
                    PauseAnimation { duration: 540 }
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; duration: 200 }
                        NumberAnimation { property: "scale"; duration: 260; easing.type: Easing.OutCubic }
                    }
                }
            },
            Transition {
                from: "shown"; to: ""
                NumberAnimation { properties: "opacity,scale"; duration: 90 }
            }
        ]

        Item {
            id: keys
            anchors.fill: parent
            Keys.onEscapePressed: panel.toggle()
            Keys.onLeftPressed: panel.move(-1)
            Keys.onRightPressed: panel.move(1)
            Keys.onReturnPressed: panel.apply(panel.files[panel.current])
            Keys.onEnterPressed: panel.apply(panel.files[panel.current])

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => panel.move((event.angleDelta.y || event.angleDelta.x) > 0 ? -1 : 1)
            }

            Repeater {
                model: panel.files
                delegate: Item {
                    id: thumb
                    required property string modelData
                    required property int index
                    // distance from the middle of the five, the short way round
                    readonly property real d: panel.offset(index - panel.position - 2)
                    width: panel.thumbW; height: panel.thumbH
                    x: content.width / 2 - width / 2 + Math.sign(d) * panel.lerp(panel.centers, d)
                    y: 0
                    scale: panel.lerp(panel.scales, d)
                    opacity: panel.lerp(panel.fade, d)
                    z: -Math.abs(d)
                    visible: opacity > 0

                    // Soft shadow: 35% black, 3px past the thumbnail, blurred moderately. The blurred item is much
                    // bigger than the shadow shape (`room`), because the blur can't spread past the item
                    // it is applied to and would otherwise be cut off at its edge.
                    Item {
                        id: shadow
                        readonly property real grow: 3
                        readonly property real room: 32
                        x: -room
                        y: -room + 5
                        width: parent.width + 2 * room
                        height: parent.height + 2 * room
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: 24
                            blur: 1.0
                        }
                        Rectangle {
                            anchors { fill: parent; margins: shadow.room - shadow.grow }
                            radius: 14 + shadow.grow
                            color: "#59000000"
                        }
                    }
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 14
                        color: panel.theme.card
                        border.width: index === panel.current ? 4 : 0
                        border.color: panel.theme.accent
                        Image {
                            anchors.fill: parent
                            // only the visible ones are decoded
                            source: thumb.visible ? "file://" + thumb.modelData : ""
                            sourceSize: Qt.size(panel.thumbW * 1.5, panel.thumbH * 1.5)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: index === panel.current ? panel.apply(thumb.modelData)
                                                           : panel.select(panel.cursor + panel.offset(index - panel.current))
                    }
                }
            }
        }
    }
}
