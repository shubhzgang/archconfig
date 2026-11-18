import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The audio mixer: slides out of the bottom of the frame's left band (from its dock button), drawn by
// the frame like the clipboard list. Everything in it is what PipeWire has now: the outputs and the
// inputs (the default one marked), the apps playing and recording (each with the outputs or inputs it
// can be moved to), and the sound cards' profiles (from pactl; cards with nothing to pick but off and
// pro audio are left out), folded until a card is clicked. Up/Down (j/k) or the mouse select a row
// (hovering selects); Left/Right (h/l) or the wheel change its volume by 5%, m mutes it, Enter makes a
// device the default or moves an app to the next one; on a card Right/Left unfold/fold its profiles
// and Enter picks one. Escape closes.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int band: 48      // the frame's left band (Frame.qml)
    readonly property int side: 10      // its bottom band
    readonly property real openW: 760
    readonly property real openH: content.implicitHeight + 32
    readonly property real contentW: openW - 32
    property real panelW: 0

    // in the bottom-left corner of the free area; only the width animates
    anchors { left: parent.left; leftMargin: band; bottom: parent.bottom; bottomMargin: side }
    width: panelW
    height: openH
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }   // rows came or went
    clip: true

    onOpenChanged: {
        if (!open) return
        unfolded = []
        sel = items[0]?.key ?? ""
        refreshCards()
        content.forceActiveFocus()
    }

    // Slides out with an ease-out and back with an ease-in, the content fading in once it has (nearly)
    // finished and going first when closing, as the clipboard list does (ListPanel.qml).
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

    // ---- devices and streams (a playback stream counts as a sink: it takes the app's audio) ----
    PwObjectTracker { objects: panel.open ? Pipewire.nodes.values : [] }   // (their properties and volumes)
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var playing: nodes.filter(n => n.isSink && n.isStream)
    readonly property var recording: nodes.filter(n => !n.isSink && n.isStream)
    function devicesFor(stream) { return stream.isSink ? outputs : inputs }
    function linkedTo(stream) {   // the device a stream plays on or records from
        const g = Pipewire.linkGroups.values.find(g => stream.isSink ? g.source === stream : g.target === stream)
        return g ? (stream.isSink ? g.target : g.source) : null
    }
    function setVolume(n, v) { n.audio.volume = Math.max(0, Math.min(1, v)) }
    function makeDefault(n) {
        if (n.isSink) Pipewire.preferredDefaultAudioSink = n
        else Pipewire.preferredDefaultAudioSource = n
    }
    function route(stream, device) {   // remembered for the app by WirePlumber
        Quickshell.execDetached(["pw-metadata", String(stream.id), "target.object", device.name])
    }
    function routeNext(stream) {
        const ds = devicesFor(stream)
        if (ds.length) route(stream, ds[(ds.indexOf(linkedTo(stream)) + 1) % ds.length])
    }
    function deviceLabel(n) { return n.description || n.nickname || n.name }
    function shortLabel(n) { return n.properties?.["device.profile.description"] || deviceLabel(n) }

    // ---- sound cards: pactl, when the panel opens and whenever the devices change ----
    property var cards: []      // { name, label, active, profiles: [{ key, label }] }
    property var unfolded: []   // the names of the cards showing their profiles
    Process {
        id: cardList
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    panel.cards = JSON.parse(text).map(c => ({
                        name: c.name,
                        label: c.properties["device.description"] || c.name,
                        active: c.active_profile,
                        profiles: Object.entries(c.profiles).filter(([k, p]) => p.available)
                                        .map(([k, p]) => ({ key: k, label: p.description || k }))
                    })).filter(c => c.profiles.some(p => p.key !== "off" && p.key !== "pro-audio"))
                } catch (e) {
                    panel.cards = []
                }
            }
        }
    }
    function refreshCards() { cardList.running = false; cardList.running = true }
    Timer { id: cardRefresh; interval: 300; onTriggered: panel.refreshCards() }
    Connections {   // a profile was switched (here or elsewhere): its devices came and went
        target: Pipewire.nodes
        enabled: panel.open
        function onValuesChanged() { cardRefresh.restart() }
    }
    function setProfile(card, profile) {
        Quickshell.execDetached(["pactl", "set-card-profile", card.name, profile.key])
        cardRefresh.restart()
    }
    function fold(card, out) {
        unfolded = unfolded.filter(n => n !== card.name).concat(out ? [card.name] : [])
    }

    // ---- the keyboard: the rows in the order they are shown, by a key that survives updates ----
    readonly property var items: {
        const out = []
        for (const n of outputs.concat(inputs, playing, recording)) out.push({ key: "n" + n.id, node: n })
        for (const c of cards) {
            out.push({ key: "c" + c.name, card: c })
            if (unfolded.includes(c.name))
                for (const p of c.profiles) out.push({ key: "p" + c.name + "/" + p.key, card: c, profile: p })
        }
        return out
    }
    property string sel: ""
    readonly property var current: items.find(i => i.key === sel) ?? null
    function step(by) {
        if (!items.length) return
        const i = items.findIndex(it => it.key === sel)
        sel = items[i < 0 ? 0 : Math.max(0, Math.min(items.length - 1, i + by))].key
    }
    function sideways(by) {   // Left/Right: the volume, a card folded or unfolded, the next profile
        const it = current
        if (!it) return
        if (it.node) setVolume(it.node, it.node.audio.volume + 0.05 * by)
        else if (it.profile) step(by)
        else fold(it.card, by > 0)
    }
    function enter() {
        const it = current
        if (!it) return
        if (it.profile) setProfile(it.card, it.profile)
        else if (it.card) fold(it.card, !unfolded.includes(it.card.name))
        else if (it.node.isStream) routeNext(it.node)
        else makeDefault(it.node)
    }

    // ---- pieces, in the other panels' style: cards, picked up when selected, dark text on them ----

    // a card, as in the clipboard list: the selected one is picked up (the accent color, it rises 6px
    // and shifts 4px right, with a deeper shadow)
    component PickCard: Rectangle {
        id: pick
        property bool selected: false
        property real lift: selected ? 1 : 0
        Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        transform: Translate { x: 4 * pick.lift; y: -6 * pick.lift }
        radius: 10
        color: selected ? panel.theme.accent : panel.theme.card
        Behavior on color { ColorAnimation { duration: 150 } }
        RectangularShadow {
            visible: panel.theme.shadows
            anchors.fill: parent; z: -1
            radius: parent.radius; offset: Qt.vector2d(0, 3 + pick.lift); blur: 6.5 + 2.2 * pick.lift; spread: 1
            color: Qt.rgba(0, 0, 0, (0.33 + 0.27 * pick.lift) * parent.color.a)
        }
    }

    component Glyph: Item {   // an icon button on a card (white on hover, as the clipboard's trash can)
        id: glyph
        property int code
        property bool on: true            // a toggle that is off is dimmed
        property int size: 22
        signal clicked()
        width: 36; height: 36
        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(glyph.code)
            color: glyphArea.containsMouse ? "white" : panel.theme.dark
            opacity: glyph.on ? 1 : 0.5
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: glyph.size
        }
        MouseArea {
            id: glyphArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: glyph.clicked()
        }
    }

    component GroupTitle: Text {   // as in the screenshot panel
        height: 34
        verticalAlignment: Text.AlignVCenter
        color: panel.theme.ink
        font.family: "CodeNewRoman Nerd Font Mono"
        font.pixelSize: 15
    }

    component Choice: Rectangle {   // a device an app can move to, on its card: the one it is on is marked
        id: choice
        property string label
        property bool chosen: false
        signal clicked()
        width: choiceRow.implicitWidth + 26
        height: 32
        radius: height / 2
        color: Qt.rgba(panel.theme.dark.r, panel.theme.dark.g, panel.theme.dark.b, choiceArea.containsMouse ? 0.2 : 0.08)
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
            id: choiceRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(choice.chosen ? 0xF043E : 0xF043D)
                color: panel.theme.dark
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 16
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: choice.label
                color: panel.theme.dark
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 14
            }
        }
        MouseArea {
            id: choiceArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.clicked()
        }
    }

    // a device or an app: (the default mark,) its name, mute, its volume, (the devices it can move to)
    component NodeRow: Item {
        id: row
        required property var modelData
        readonly property var node: modelData
        readonly property string key: "n" + node.id
        readonly property bool selected: panel.sel === key
        readonly property bool stream: node.isStream
        readonly property bool isDefault: node === (node.isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource)
        readonly property var on: stream ? panel.linkedTo(node) : null
        readonly property real level: node.audio?.volume ?? 0
        readonly property bool muted: node.audio?.muted ?? false
        width: panel.contentW
        height: rowContent.implicitHeight + 20

        HoverHandler { onHoveredChanged: if (hovered) panel.sel = row.key }   // hovering selects

        PickCard {
            anchors.fill: parent
            selected: row.selected

            Column {
                id: rowContent
                x: 12; y: 10
                width: parent.width - 24
                spacing: 2

                Row {
                    width: parent.width
                    spacing: 4
                    Glyph {   // the default device: a click makes this one it
                        visible: !row.stream
                        anchors.verticalCenter: parent.verticalCenter
                        code: row.isDefault ? 0xF043E : 0xF043D
                        size: 20
                        onClicked: panel.makeDefault(row.node)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (row.stream ? 0 : 40)
                        height: 36
                        leftPadding: row.stream ? 8 : 0
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        readonly property string media: row.node.properties?.["media.name"] ?? ""
                        text: row.stream
                            ? (row.node.properties?.["application.name"] || row.node.description || row.node.name)
                              + (media ? "  <font color=\"" + Qt.rgba(panel.theme.dark.r, panel.theme.dark.g, panel.theme.dark.b, 0.6) + "\">"
                                         + media.replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</font>" : "")
                            : panel.deviceLabel(row.node)
                        color: panel.theme.dark
                        font.family: "CodeNewRoman Nerd Font Mono"
                        font.pixelSize: 16
                        font.bold: row.selected
                    }
                }

                Row {
                    width: parent.width
                    Glyph {   // mute
                        anchors.verticalCenter: parent.verticalCenter
                        code: row.node.isSink
                            ? (row.muted || row.level === 0 ? 0xF0581 : row.level < 0.34 ? 0xF057F : row.level < 0.67 ? 0xF0580 : 0xF057E)
                            : (row.muted ? 0xF036D : 0xF036C)
                        on: !row.muted
                        onClicked: row.node.audio.muted = !row.muted
                    }
                    Item {
                        id: slider
                        width: parent.width - 36 - 64
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 16
                            height: 4
                            radius: 2
                            color: Qt.rgba(panel.theme.dark.r, panel.theme.dark.g, panel.theme.dark.b, 0.25)
                            Rectangle {
                                width: parent.width * Math.min(1, row.level)
                                height: parent.height
                                radius: 2
                                color: panel.theme.dark
                                opacity: row.muted ? 0.4 : 1
                            }
                            Rectangle {   // the knob
                                x: parent.width * Math.min(1, row.level) - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 14; radius: 7
                                color: sliderArea.containsMouse || sliderArea.pressed ? "white" : panel.theme.dark
                            }
                        }
                        MouseArea {
                            id: sliderArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: event => panel.setVolume(row.node, (event.x - 8) / (width - 16))
                            onPositionChanged: event => { if (pressed) panel.setVolume(row.node, (event.x - 8) / (width - 16)) }
                        }
                        WheelHandler {   // 5% a notch
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => panel.setVolume(row.node, row.level + event.angleDelta.y / 120 * 0.05)
                        }
                    }
                    Text {
                        width: 64
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: 4
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(row.level * 100) + "%"
                        color: panel.theme.dark
                        opacity: 0.75
                        font.family: "CodeNewRoman Nerd Font Mono"
                        font.pixelSize: 14
                    }
                }

                Flow {   // an app: the devices it can move to
                    visible: row.stream
                    width: parent.width
                    spacing: 8
                    topPadding: 4
                    bottomPadding: 2
                    Repeater {
                        model: row.stream ? panel.devicesFor(row.node) : []
                        delegate: Choice {
                            required property var modelData
                            label: panel.shortLabel(modelData)
                            chosen: modelData === row.on
                            onClicked: panel.route(row.node, modelData)
                        }
                    }
                }
            }
        }
    }

    // a sound card: a card with its name and profile; unfolded, below it the profiles it can switch to,
    // as the screenshot panel's chips (the one in use marked)
    component CardRow: Column {
        id: cardRow
        required property var modelData
        readonly property var card: modelData
        readonly property string key: "c" + card.name
        readonly property bool unfolded: panel.unfolded.includes(card.name)
        width: panel.contentW
        spacing: 10

        Item {
            width: parent.width
            height: 52
            HoverHandler { onHoveredChanged: if (hovered) panel.sel = cardRow.key }
            PickCard {
                anchors.fill: parent
                selected: panel.sel === cardRow.key
                Text {
                    id: chevron
                    x: 12
                    width: 36
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: String.fromCodePoint(cardRow.unfolded ? 0xF0140 : 0xF0142)
                    color: panel.theme.dark
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 20
                }
                Text {
                    id: cardName
                    anchors { left: chevron.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    text: cardRow.card.label
                    color: panel.theme.dark
                    font.family: "CodeNewRoman Nerd Font Mono"
                    font.pixelSize: 16
                    font.bold: panel.sel === cardRow.key
                }
                Text {
                    anchors { left: cardName.right; leftMargin: 16; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: cardRow.card.profiles.find(p => p.key === cardRow.card.active)?.label ?? cardRow.card.active
                    color: panel.theme.dark
                    opacity: 0.7
                    font.family: "CodeNewRoman Nerd Font Mono"
                    font.pixelSize: 14
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.fold(cardRow.card, !cardRow.unfolded)
                }
            }
        }

        Flow {
            visible: cardRow.unfolded
            x: 12
            width: parent.width - 12
            spacing: 8
            bottomPadding: 4
            Repeater {
                model: cardRow.unfolded ? cardRow.card.profiles : []
                delegate: Rectangle {
                    id: profile
                    required property var modelData
                    readonly property string key: "p" + cardRow.card.name + "/" + modelData.key
                    readonly property bool chosen: modelData.key === cardRow.card.active
                    width: profileRow.implicitWidth + 32
                    height: 36
                    radius: height / 2
                    color: panel.sel === key ? panel.theme.accent : panel.theme.card
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { onHoveredChanged: if (hovered) panel.sel = profile.key }   // hovering selects
                    Row {
                        id: profileRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String.fromCodePoint(profile.chosen ? 0xF043E : 0xF043D)
                            color: panel.theme.dark
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 18
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: profile.modelData.label
                            color: panel.theme.dark
                            font.family: "CodeNewRoman Nerd Font Mono"
                            font.pixelSize: 15
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.setProfile(cardRow.card, profile.modelData)
                    }
                }
            }
        }
    }

    Column {
        id: content
        x: 16; y: 16
        width: panel.contentW
        spacing: 10
        opacity: 0
        visible: opacity > 0

        Keys.onEscapePressed: panel.toggle()
        Keys.onReturnPressed: panel.enter()
        Keys.onEnterPressed: panel.enter()
        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Up || k === Qt.Key_K) panel.step(-1)
            else if (k === Qt.Key_Down || k === Qt.Key_J) panel.step(1)
            else if (k === Qt.Key_Left || k === Qt.Key_H) panel.sideways(-1)
            else if (k === Qt.Key_Right || k === Qt.Key_L) panel.sideways(1)
            else if (k === Qt.Key_M && panel.current?.node) panel.current.node.audio.muted = !panel.current.node.audio.muted
            else return
            event.accepted = true
        }

        GroupTitle { text: "Outputs"; visible: panel.outputs.length > 0 }
        Repeater { model: panel.outputs; delegate: NodeRow {} }
        GroupTitle { text: "Inputs"; visible: panel.inputs.length > 0 }
        Repeater { model: panel.inputs; delegate: NodeRow {} }
        GroupTitle { text: "Playing"; visible: panel.playing.length > 0 }
        Repeater { model: panel.playing; delegate: NodeRow {} }
        GroupTitle { text: "Recording"; visible: panel.recording.length > 0 }
        Repeater { model: panel.recording; delegate: NodeRow {} }
        GroupTitle { text: "Cards"; visible: panel.cards.length > 0 }
        Repeater { model: panel.cards; delegate: CardRow {} }
    }
}
