import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Wallpaper picker that grows up out of the bottom band, drawn by the frame like the other panels.
// A carousel of five equal thumbnails with a smaller one peeking in at each end. Left/Right (or the
// wheel) move the selection across the five; the carousel only slides, by one, when the selection
// steps onto a peeking one. It wraps around at both ends (after the last wallpaper comes the first).
// It opens on the current wallpaper. Selecting a wallpaper (a click, the arrows or the wheel) applies it
// (hypr/wallpaper.sh), leaving the picker open; Enter applies the selected one and closes it, Escape closes.
// Below the carousel: plain-color wallpapers, and color swatches (one color, or two) that theme
// everything from their colors instead of the wallpaper's until "auto" is picked again, with switches
// for how a single color is grown into a palette (each harmony shown as the three main colors it gives)
// and for the shell's style.
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
    readonly property real controlsH: 112   // the rows below the carousel
    readonly property real openH: thumbH + controlsH + 2 * pad
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
        settle.restart()
    }
    // the arrows and the wheel apply the wallpaper they stop on: each apply re-themes everything, so
    // stepping through several in a row only previews them
    Timer {
        id: settle
        interval: 400
        onTriggered: panel.apply(panel.files[panel.current], false)
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
    Component.onCompleted: { lister.running = true; previewHarmonies() }

    // the wallpaper wpaperd is showing now ("MONITOR: /path")
    Process {
        id: now
        command: ["wpaperctl", "get-all"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /: (.+)/.exec(text)
                panel.show(Math.max(0, panel.files.indexOf(m ? m[1].trim() : "")))
            }
        }
    }

    function move(by) { if (files.length) select(cursor + by) }
    function apply(path, close) {
        if (!path) return
        settle.stop()
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/wallpaper.sh", path])
        theme.commitPreview(path)
        if (close) panel.toggle()
    }
    // ---- plain wallpapers and color swatches (hypr/wallpaper.sh --plain / --swatch / --harmony) ----
    readonly property string plainDir: Quickshell.env("HOME") + "/wallpapers/plain"
    readonly property var plains: ["#1C1C1E", "#3A3A3C", "#8E8E93", "#C7C7CC", "#8E8A84", "#1F3A5F", "#3A6EA5",
                                   "#2F7F86", "#4FB3C8", "#4F8A5B", "#E4B94A", "#D9783B", "#B83A3A", "#D4708F", "#6E4E9E"]
    readonly property var swatches: [
        ["#1E2433"], ["#E8E1D3"], ["#E0413A"], ["#FF6A2B"], ["#F7C948"], ["#B6E35A"], ["#3FBF6B"], ["#7FD6B7"],
        ["#3CC4E0"], ["#3A7BFF"], ["#5856D6"], ["#9B5CF6"], ["#FF5FA2"], ["#F2B8A6"],
        ["#1E2433", "#E8E1D3"], ["#3A7BFF", "#3CC4E0"], ["#FF5FA2", "#FF6A2B"], ["#9B5CF6", "#FF5FA2"],
        ["#3FBF6B", "#B6E35A"], ["#5856D6", "#7FD6B7"], ["#E0413A", "#F7C948"], ["#1F3A5F", "#F2B8A6"]
    ]
    readonly property var harmonies: ["monochrome", "complementary", "split", "analogous", "triadic"]
    // the harmony only matters for a single color: a one-color swatch, or a plain wallpaper with none
    readonly property string baseColor: {
        if (theme.swatch.length === 1) return theme.swatch[0]
        const m = theme.swatch.length === 0 && /\/wallpapers\/plain\/([0-9A-F]{6})\.png$/.exec(theme.wallpaper)
        return m ? "#" + m[1] : ""
    }
    readonly property bool singleColor: baseColor !== ""
    // color1..color3 that each harmony gives the base color (the same code that applies it, wal/swatch_scheme.py)
    property var harmonyColors: ({})
    // (the command is set here rather than bound: a change handler runs before the bindings that
    // depend on the same property have caught up, so a bound command still had the old color)
    function previewHarmonies() {
        if (!baseColor) return
        harmonyPreview.command = ["python3", Quickshell.env("HOME") + "/.config/wal/swatch_scheme.py", "--preview", baseColor]
        harmonyPreview.running = true
    }
    onBaseColorChanged: previewHarmonies()
    Process {
        id: harmonyPreview
        stdout: StdioCollector {
            onStreamFinished: { try { panel.harmonyColors = JSON.parse(text) } catch (e) {} }
        }
    }
    function run(args) {   // the colors change once the wal files are written: drop any preview first
        theme.endPreview()
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/wallpaper.sh"].concat(args))
    }

    onOpenChanged: {
        if (open) { keys.forceActiveFocus(); now.running = true }
        else {
            if (settle.running) apply(files[current], false)   // closed right after an arrow: apply that one now
            theme.endPreview()   // (does nothing while a wallpaper is being applied) back to the real colors
        }
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
            Keys.onReturnPressed: panel.apply(panel.files[panel.current], true)
            Keys.onEnterPressed: panel.apply(panel.files[panel.current], true)

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
                        onClicked: {
                            if (index !== panel.current) panel.select(panel.cursor + panel.offset(index - panel.current))
                            panel.apply(thumb.modelData, false)
                        }
                    }
                }
            }
        }

        Row {   // plain-color wallpapers
            id: plainRow
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: panel.thumbH + 34 }
            spacing: 12
            Repeater {
                model: panel.plains
                delegate: Swatch {
                    required property string modelData
                    theme: panel.theme
                    width: 56; height: 32
                    colors: [modelData]
                    selected: panel.theme.wallpaper === panel.plainDir + "/" + modelData.slice(1) + ".png"
                    onClicked: panel.run(["--plain", modelData])
                }
            }
        }

        Row {   // color swatches, then the harmony and style switches
            anchors { horizontalCenter: parent.horizontalCenter; top: plainRow.bottom; topMargin: 18 }
            spacing: 36
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Swatch {   // auto: the wallpaper's own colors
                    theme: panel.theme
                    image: panel.theme.wallpaper
                    selected: panel.theme.swatch.length === 0
                    onClicked: panel.run(["--swatch", "auto"])
                }
                Repeater {
                    model: panel.swatches
                    delegate: Swatch {
                        required property var modelData
                        theme: panel.theme
                        colors: modelData
                        selected: panel.theme.swatch.join() === modelData.join()
                        onClicked: panel.run(["--swatch", modelData.join()])
                    }
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                opacity: panel.singleColor ? 1 : 0.4
                Repeater {
                    model: panel.harmonies
                    delegate: Swatch {
                        required property string modelData
                        theme: panel.theme
                        colors: panel.singleColor ? panel.harmonyColors[modelData] ?? [] : []
                        selected: panel.theme.harmony === modelData
                        onClicked: panel.run(["--harmony", modelData])
                    }
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Chip { theme: panel.theme; label: "Paper"; selected: !panel.theme.glass; onClicked: panel.theme.setStyle("paper") }
                Chip { theme: panel.theme; label: "Glass"; selected: panel.theme.glass; onClicked: panel.theme.setStyle("glass") }
            }
        }
    }
}
