import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// The media panel: slides out of the left band beside the track in it (MediaStrip.qml), drawn by the
// frame like the other panels. The album art, the track, how far it has played (click or drag to
// seek) and the usual controls. With more than one player, dots on the right switch between them (it
// opens on the one in the strip; scrolling switches too). Below, the player's own volume and which
// output it plays on (only its audio: the device volume and the other apps stay as they are), and the
// sound card's output for all audio (speakers or headphones). Space plays or pauses, Left / Right skip, Up / Down switch players,
// Escape closes.
Item {
    id: panel
    required property var theme
    required property var media
    property bool open: false
    signal toggle()

    readonly property int band: 48       // the frame's left band (Frame.qml)
    readonly property bool several: media.players.length > 1
    readonly property real openW: several ? 600 : 560    // room on the right for the players' dots
    readonly property real openH: content.implicitHeight + 48
    property real panelW: 0
    // the player shown here: the strip's when it opens, or one picked with the dots
    property var viewed: null
    readonly property var player: media.players.includes(viewed) ? viewed : media.player
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property bool playing: player?.isPlaying ?? false
    function cycle(step) {
        const ps = media.players, i = ps.indexOf(player)
        if (ps.length > 1) viewed = ps[(i + step + ps.length) % ps.length]
    }

    // in the middle of the left band, like the track in it; only the width animates
    anchors { left: parent.left; leftMargin: band; verticalCenter: parent.verticalCenter }
    width: panelW
    height: openH
    clip: true

    // the position isn't sent as it changes: ask for it every second while it can be seen
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: panel.open && panel.playing
        onTriggered: panel.player.positionChanged()
    }
    onOpenChanged: if (open) { viewed = media.player; if (player) player.positionChanged(); keys.forceActiveFocus(); checkOutput() }
    onPlayerChanged: if (open && player) player.positionChanged()

    // Slides out with an ease-out and back with an ease-in; the content fades in once it has (nearly)
    // finished, and is the first thing to go when closing. (As in ListPanel.qml.)
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

    // ---- the player's audio: its streams in PipeWire. MPRIS doesn't say which ones are a player's, so
    // they are matched by name (the player's desktop entry or name against the stream's app or binary).
    PwObjectTracker { objects: panel.open ? Pipewire.nodes.values : [] }   // (their properties and volumes)
    readonly property var names: player ? [player.desktopEntry, player.identity].filter(k => k).map(k => k.toLowerCase()) : []
    function belongs(node) {
        const app = (node.properties?.["application.name"] ?? "").toLowerCase()
        const bin = (node.properties?.["application.process.binary"] ?? "").toLowerCase()
        return names.some(k => k === app || k === bin || (app !== "" && (app.includes(k) || k.includes(app))))
    }
    // (a playback stream counts as a sink too: it takes the app's audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio && belongs(n))
    readonly property var stream: streams[0] ?? null
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    // where it plays now: asked of pactl when the panel opens, shows another player, or moves it
    property string outputName: ""
    readonly property var output: outputs.find(n => n.name === outputName) ?? null
    function checkOutput() {
        if (!open || !stream) { outputName = ""; return }
        where.running = false
        where.running = true
    }
    onStreamChanged: checkOutput()
    Process {
        id: where
        command: ["sh", "-c", "pactl -f json list sink-inputs; echo; pactl -f json list short sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [inputs, sinks] = text.split("\n").filter(l => l.trim()).map(l => JSON.parse(l))
                    const input = inputs.find(i => i.properties["object.id"] === String(panel.stream?.id))
                    panel.outputName = sinks.find(s => s.index === input?.sink)?.name ?? ""
                } catch (e) {
                    panel.outputName = ""
                }
            }
        }
    }
    Timer { id: recheck; interval: 400; onTriggered: panel.checkOutput() }   // once it has moved
    function setVolume(v) { for (const n of streams) n.audio.volume = Math.max(0, Math.min(1, v)) }
    function route(sink) {   // remembered for the app by WirePlumber
        for (const n of streams) Quickshell.execDetached(["pw-metadata", String(n.id), "target.object", sink.name])
        recheck.restart()
    }

    // the mouse wheel switches players too: one per notch (a touchpad's small steps add up to one)
    WheelHandler {
        enabled: panel.open && panel.several
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real sum: 0
        onWheel: event => {
            sum += event.angleDelta.y
            while (Math.abs(sum) >= 120) {
                panel.cycle(sum > 0 ? -1 : 1)
                sum -= Math.sign(sum) * 120
            }
        }
    }

    Item {
        id: keys
        Keys.onEscapePressed: panel.toggle()
        Keys.onSpacePressed: if (panel.player?.canTogglePlaying) panel.player.togglePlaying()
        Keys.onLeftPressed: if (panel.player?.canGoPrevious) panel.player.previous()
        Keys.onRightPressed: if (panel.player?.canGoNext) panel.player.next()
        Keys.onUpPressed: panel.cycle(-1)
        Keys.onDownPressed: panel.cycle(1)
    }

    component Glyph: Item {   // an icon button
        id: glyph
        property int code
        property bool on: true            // a toggle that is off is dimmed
        property bool usable: true
        property int size: 28
        signal clicked()
        width: 52; height: 52
        opacity: usable ? 1 : 0.35
        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(glyph.code)
            color: glyphArea.containsMouse && glyph.usable ? panel.theme.hover : panel.theme.ink
            opacity: glyph.on ? 1 : 0.5
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: glyph.size
        }
        MouseArea {
            id: glyphArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: glyph.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: glyph.clicked()
        }
    }

    Column {
        id: content
        x: 24; y: 24
        width: 512                   // fixed, so nothing reflows while the panel slides out
        spacing: 0
        opacity: 0
        visible: opacity > 0

        Item {   // the album art, with a soft shadow
            width: parent.width
            height: width
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(panel.theme.ink.r, panel.theme.ink.g, panel.theme.ink.b, 0.12)
                RectangularShadow {
                    anchors.fill: parent; z: -1
                    radius: parent.radius; offset: Qt.vector2d(0, 4); blur: 8.6; spread: 1
                    color: Qt.rgba(0, 0, 0, 0.4 * parent.color.a)
                }
            }
            ClippingRectangle {
                anchors.fill: parent
                radius: 14
                color: "transparent"
                Image {
                    anchors.fill: parent
                    source: panel.art
                    sourceSize: Qt.size(1024, 1024)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Text {   // no art: a note
                anchors.centerIn: parent
                visible: panel.art === ""
                text: String.fromCodePoint(0xF075A)
                color: panel.theme.ink
                opacity: 0.5
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 120
            }
        }

        Item { width: 1; height: 18 }
        Text {   // which player
            width: parent.width
            text: panel.player?.identity ?? ""
            elide: Text.ElideRight
            color: panel.theme.ink
            opacity: 0.5
            font.family: "CodeNewRoman Nerd Font Mono"
            font.pixelSize: 13
        }
        Item { width: 1; height: 4 }
        Text {
            width: parent.width
            text: panel.title || "Nothing playing"
            elide: Text.ElideRight
            color: panel.theme.ink
            font.family: "CodeNewRoman Nerd Font Mono"
            font.pixelSize: 22
            font.bold: true
        }
        Item { width: 1; height: 6 }
        Text {
            width: parent.width
            text: [panel.artist, panel.album].filter(s => s).join("  ·  ")
            elide: Text.ElideRight
            color: panel.theme.ink
            opacity: 0.7
            font.family: "CodeNewRoman Nerd Font Mono"
            font.pixelSize: 16
        }

        Item { width: 1; height: 18 }
        Item {   // how far it has played; click or drag to seek
            id: progress
            width: parent.width
            height: 20
            readonly property real length: panel.player?.length ?? 0
            readonly property real fraction: length > 0 ? Math.min(1, (panel.player?.position ?? 0) / length) : 0
            readonly property bool seekable: (panel.player?.canSeek ?? false) && length > 0
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(panel.theme.ink.r, panel.theme.ink.g, panel.theme.ink.b, 0.25)
                Rectangle {
                    width: parent.width * progress.fraction
                    height: parent.height
                    radius: 2
                    color: panel.theme.ink
                }
            }
            Rectangle {   // the knob, while the mouse is over it
                x: track.width * progress.fraction - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7
                color: panel.theme.ink
                visible: seek.containsMouse && progress.seekable
            }
            MouseArea {
                id: seek
                anchors.fill: parent
                hoverEnabled: true
                enabled: progress.seekable
                cursorShape: Qt.PointingHandCursor
                function seekTo(x) { panel.player.position = Math.max(0, Math.min(1, x / width)) * progress.length }
                onPressed: event => seekTo(event.x)
                onPositionChanged: event => { if (pressed) seekTo(event.x) }
            }
        }
        Item {
            width: parent.width
            height: 22
            Text {
                text: panel.media.time(panel.player?.position ?? 0)
                color: panel.theme.ink
                opacity: 0.7
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 14
            }
            Text {
                anchors.right: parent.right
                text: progress.length > 0 ? panel.media.time(progress.length) : ""
                color: panel.theme.ink
                opacity: 0.7
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 14
            }
        }

        Item { width: 1; height: 8 }
        Row {   // shuffle, previous, play / pause, next, repeat
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF049D
                size: 24
                usable: panel.player?.shuffleSupported ?? false
                on: panel.player?.shuffle ?? false
                onClicked: panel.player.shuffle = !panel.player.shuffle
            }
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF04AE
                usable: panel.player?.canGoPrevious ?? false
                onClicked: panel.player.previous()
            }
            Rectangle {   // play / pause: a filled circle
                anchors.verticalCenter: parent.verticalCenter
                width: 64; height: 64; radius: 32
                color: playArea.containsMouse ? panel.theme.hover : panel.theme.ink
                opacity: panel.player?.canTogglePlaying ? 1 : 0.35
                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: panel.playing ? 0 : 2   // the triangle looks centred
                    text: String.fromCodePoint(panel.playing ? 0xF03E4 : 0xF040A)
                    color: panel.theme.textOnInk
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 32
                }
                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: panel.player?.canTogglePlaying ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.player.togglePlaying()
                }
            }
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF04AD
                usable: panel.player?.canGoNext ?? false
                onClicked: panel.player.next()
            }
            Glyph {   // off, the whole list, this track
                anchors.verticalCenter: parent.verticalCenter
                readonly property int loop: panel.player?.loopState ?? MprisLoopState.None
                code: loop === MprisLoopState.Track ? 0xF0458 : 0xF0456
                size: 24
                usable: panel.player?.loopSupported ?? false
                on: loop !== MprisLoopState.None
                onClicked: panel.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                                                  : loop === MprisLoopState.Playlist ? MprisLoopState.Track
                                                  : MprisLoopState.None
            }
        }

        Item { width: 1; height: 14 }
        Item {   // the player's own volume: mute, the slider (or scroll on it), how loud
            id: volume
            width: parent.width
            height: 40
            enabled: panel.stream !== null
            opacity: enabled ? 1 : 0.35
            readonly property real level: panel.stream?.audio.volume ?? 0
            readonly property bool muted: panel.stream?.audio.muted ?? false
            Glyph {
                x: -12
                anchors.verticalCenter: parent.verticalCenter
                code: volume.muted || volume.level === 0 ? 0xF0581 : volume.level < 0.34 ? 0xF057F : volume.level < 0.67 ? 0xF0580 : 0xF057E
                size: 22
                usable: volume.enabled
                on: !volume.muted
                onClicked: { const m = !volume.muted; for (const n of panel.streams) n.audio.muted = m }
            }
            Item {
                id: slider
                x: 44
                width: parent.width - 44 - 56
                height: parent.height
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(panel.theme.ink.r, panel.theme.ink.g, panel.theme.ink.b, 0.25)
                    Rectangle {
                        width: parent.width * Math.min(1, volume.level)
                        height: parent.height
                        radius: 2
                        color: panel.theme.ink
                        opacity: volume.muted ? 0.4 : 1
                    }
                }
                Rectangle {   // the knob
                    x: slider.width * Math.min(1, volume.level) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7
                    color: volumeArea.containsMouse || volumeArea.pressed ? panel.theme.hover : panel.theme.ink
                }
                MouseArea {
                    id: volumeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: event => panel.setVolume(event.x / width)
                    onPositionChanged: event => { if (pressed) panel.setVolume(event.x / width) }
                }
                WheelHandler {   // 5% a notch (and not a switch of players, as elsewhere on the panel)
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => panel.setVolume(volume.level + event.angleDelta.y / 120 * 0.05)
                }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: Math.round(volume.level * 100) + "%"
                color: panel.theme.ink
                opacity: 0.7
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 14
            }
        }
        Item { width: 1; height: 8 }
        Flow {   // where the player plays: pick an output for it alone
            width: parent.width
            spacing: 8
            enabled: panel.stream !== null
            opacity: enabled ? 1 : 0.35
            Repeater {
                model: panel.outputs
                delegate: Chip {
                    required property var modelData
                    theme: panel.theme
                    label: modelData.nickname || modelData.description || modelData.name
                    selected: modelData === panel.output
                    onClicked: panel.route(modelData)
                }
            }
        }
        Item { width: 1; height: 10 }
        Row {   // the sound card's output, for all audio: the speakers (TOSLINK) or the headphones (line out)
            spacing: 8
            // which one is on, from its sink (hypr/scripts/toggle_audio_output.sh switches the card's profile)
            readonly property bool headphones: Pipewire.nodes.values.some(n => n.name === "alsa_output.pci-0000_17_00.6.analog-stereo")
            readonly property bool speakers: Pipewire.nodes.values.some(n => n.name === "alsa_output.pci-0000_17_00.6.iec958-ac3-surround-51")
            function pick(which) {
                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/toggle_audio_output.sh", which])
                recheck.restart()   // the player's stream moves with it
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "All audio"
                color: panel.theme.ink
                opacity: 0.7
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 14
            }
            Chip {
                theme: panel.theme
                label: "5.1 Speakers"
                selected: parent.speakers
                onClicked: parent.pick("speakers")
            }
            Chip {
                theme: panel.theme
                label: "Headphones"
                selected: parent.headphones
                onClicked: parent.pick("headphones")
            }
        }
    }

    Column {   // the players, as dots (like the workspace dots): the one shown is a tall pill;
               // playing ones are raised, paused ones flat and dimmer
        x: 24 + content.width + 12
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        spacing: 2
        visible: panel.several
        opacity: content.opacity
        Repeater {
            model: panel.media.players
            delegate: Item {
                id: dot
                required property var modelData
                readonly property bool shown: modelData === panel.player
                width: 40
                height: (shown ? 34 : 19) + 6
                Behavior on height { NumberAnimation { duration: 170 } }
                Rectangle {
                    anchors.centerIn: parent
                    width: 17
                    height: dot.shown ? 34 : 17
                    radius: 8.5
                    Behavior on height { NumberAnimation { duration: 170 } }
                    color: dotArea.containsMouse ? (dot.shown ? panel.theme.accent2 : panel.theme.accent)
                         : dot.shown ? panel.theme.accent
                         : dot.modelData.isPlaying ? panel.theme.accent2 : panel.theme.accent3
                    Behavior on color { ColorAnimation { duration: 300 } }
                    RectangularShadow {
                        anchors.fill: parent; z: -1
                        visible: dot.shown || dot.modelData.isPlaying
                        radius: parent.radius; offset: Qt.vector2d(0, 2); blur: 2.9; spread: 1
                        color: Qt.rgba(0, 0, 0, 0.65)
                    }
                }
                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.viewed = dot.modelData
                }
            }
        }
    }
}
