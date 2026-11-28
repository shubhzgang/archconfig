import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth

// Bluetooth, grown out of the top band at the left (from the bar's bluetooth icon), drawn by the frame
// like the calendar. Switches for the adapter on or off and for this computer visible to other devices
// (and pairable; BlueZ turns it off again after its discoverable timeout), a button that searches for
// devices (until it is clicked again or the panel closes), and the devices: connected, paired, and
// found by the search (the ones with a name). A click on a device disconnects or connects it, or pairs
// with it (then trusts and connects it), or cancels the pairing; the trash can forgets a paired one.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int band: 48
    readonly property real openW: 520
    readonly property real openH: content.implicitHeight + 32
    readonly property real contentW: openW - 32
    property real panelW: 0
    property real panelH: 0

    anchors { top: parent.top; left: parent.left; leftMargin: band }
    width: panelW
    height: band + panelH
    clip: true

    onOpenChanged: if (!open && adapter?.discovering) adapter.discovering = false

    // Same shape of animation as the calendar's, the content fading in once it has (nearly) grown;
    // open, it follows the rows as they come and go
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
    Behavior on panelH { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // ---- the adapter and its devices ----
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: on ? adapter.devices.values.slice().sort((a, b) => a.name.localeCompare(b.name)) : []
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var paired: devices.filter(d => !d.connected && d.paired)
    readonly property var found: devices.filter(d => !d.connected && !d.paired && d.deviceName !== "")

    function setVisible(v) {
        if (v) adapter.pairable = true
        adapter.discoverable = v
    }
    function busy(d) { return d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting }

    // pairing with a device, then trusting (it reconnects by itself later) and connecting it
    property var pairing: []   // their addresses
    function act(d) {
        if (d.pairing) d.cancelPair()
        else if (busy(d)) return
        else if (d.connected) d.disconnect()
        else if (d.paired) d.connect()
        else { pairing = pairing.concat([d.address]); d.pair() }
    }
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() {
                if (!modelData.paired || !panel.pairing.includes(modelData.address)) return
                panel.pairing = panel.pairing.filter(a => a !== modelData.address)
                modelData.trusted = true
                modelData.connect()
            }
            function onPairingChanged() {   // it failed or was cancelled
                if (!modelData.pairing && !modelData.paired) panel.pairing = panel.pairing.filter(a => a !== modelData.address)
            }
        }
    }

    function status(d) {
        if (d.pairing) return "Pairing…"
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…"
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
        if (d.connected) return d.batteryAvailable ? Math.round(d.battery * (d.battery <= 1 ? 100 : 1)) + "%" : "Connected"
        return ""
    }
    function action(d) {   // what a click does, shown on hover
        if (d.pairing) return "Cancel"
        if (busy(d)) return status(d)
        return d.connected ? "Disconnect" : d.paired ? "Connect" : "Pair"
    }
    function glyph(icon) {   // BlueZ's icon names (freedesktop's)
        if (icon.startsWith("audio-headset") || icon.startsWith("audio-headphones")) return 0xF02CB
        if (icon.startsWith("audio")) return 0xF04C3
        if (icon === "input-mouse") return 0xF037D
        if (icon === "input-keyboard") return 0xF030C
        if (icon === "input-gaming") return 0xF0297
        if (icon.startsWith("phone")) return 0xF011C
        if (icon === "computer") return 0xF0322
        return 0xF00AF
    }

    // ---- pieces, as the audio mixer's ----

    // a card, picked up when hovered (the accent color, it rises 6px and shifts 4px right, with a deeper shadow)
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

    component GroupTitle: Text {
        height: 34
        verticalAlignment: Text.AlignVCenter
        color: panel.theme.ink
        font.family: "CodeNewRoman Nerd Font Mono"
        font.pixelSize: 15
    }

    component Switch: Item {   // as the wallpaper panel's: on is the knob right, the track filled
        id: sw
        property string label
        property bool on: false
        property bool enabled: true
        signal clicked()
        width: swRow.implicitWidth
        height: swRow.implicitHeight
        opacity: enabled ? 1 : 0.4
        Row {
            id: swRow
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sw.label
                color: panel.theme.ink
                opacity: sw.on ? 1 : 0.5
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 15
            }
            Rectangle {   // the track
                anchors.verticalCenter: parent.verticalCenter
                width: 46; height: 26
                radius: height / 2
                color: sw.on ? panel.theme.ink : "transparent"
                border.width: 1
                border.color: Qt.rgba(panel.theme.ink.r, panel.theme.ink.g, panel.theme.ink.b, sw.on ? 0 : 0.45)
                Behavior on color { ColorAnimation { duration: 150 } }
                Rectangle {   // the knob
                    width: 18; height: 18
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: sw.on ? parent.width - width - 4 : 4
                    color: sw.on ? panel.theme.textOnInk : panel.theme.ink
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
            }
        }
        MouseArea {   // over the whole switch, its label included
            anchors.fill: parent
            enabled: sw.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.clicked()
        }
    }

    // a device: its icon, its name, its state (on hover, what a click does), the trash can if paired
    component DeviceRow: Item {
        id: row
        required property var modelData
        readonly property var device: modelData
        width: panel.contentW
        height: 52

        HoverHandler { id: hover }

        PickCard {
            anchors.fill: parent
            selected: hover.hovered

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.act(row.device)
            }
            Text {
                id: icon
                x: 12
                width: 36
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: String.fromCodePoint(panel.glyph(row.device.icon))
                color: panel.theme.dark
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 20
            }
            Text {
                anchors { left: icon.right; leftMargin: 4; right: hint.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                text: row.device.name
                color: panel.theme.dark
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 16
                font.bold: hover.hovered
            }
            Text {
                id: hint
                anchors { right: forget.visible ? forget.left : parent.right; rightMargin: forget.visible ? 4 : 16; verticalCenter: parent.verticalCenter }
                text: hover.hovered ? panel.action(row.device) : panel.status(row.device)
                color: panel.theme.dark
                opacity: 0.7
                font.family: "CodeNewRoman Nerd Font Mono"
                font.pixelSize: 14
            }
            Item {   // forget it (white on hover, as the clipboard's trash can)
                id: forget
                visible: row.device.paired
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 36; height: 36
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF01B4)
                    color: forgetArea.containsMouse ? "white" : panel.theme.dark
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 20
                }
                MouseArea {
                    id: forgetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.device.forget()
                }
            }
        }
    }

    MouseArea { anchors.fill: parent }   // a click between the rows doesn't close the panel

    Column {
        id: content
        x: 16; y: panel.band + 16
        width: panel.contentW
        spacing: 10
        opacity: panel.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {   // fades in once the shape has (nearly) finished growing
            SequentialAnimation {
                PauseAnimation { duration: panel.open ? 300 : 0 }
                NumberAnimation { duration: panel.open ? 150 : 100 }
            }
        }

        Item {   // the switches and the search
            width: parent.width
            height: 34
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 24
                Switch {
                    label: "Bluetooth"
                    on: panel.on
                    enabled: !!panel.adapter
                    onClicked: panel.adapter.enabled = !panel.on
                }
                Switch {
                    label: "Visible"
                    on: panel.on && panel.adapter.discoverable
                    enabled: panel.on
                    onClicked: panel.setVisible(!panel.adapter.discoverable)
                }
            }
            Chip {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                theme: panel.theme
                label: panel.on && panel.adapter.discovering ? "Searching…" : "Search"
                selected: panel.on && panel.adapter.discovering
                opacity: panel.on ? 1 : 0.4
                enabled: panel.on
                onClicked: panel.adapter.discovering = !panel.adapter.discovering
            }
        }

        GroupTitle {
            visible: !panel.on
            text: panel.adapter ? "Bluetooth is off" : "No bluetooth controller (is bluetooth.service running?)"
            opacity: 0.6
        }
        GroupTitle { text: "Connected"; visible: panel.connected.length > 0 }
        Repeater { model: panel.connected; delegate: DeviceRow {} }
        GroupTitle { text: "Paired"; visible: panel.paired.length > 0 }
        Repeater { model: panel.paired; delegate: DeviceRow {} }
        GroupTitle {
            visible: panel.on && (panel.found.length > 0 || panel.adapter.discovering)
            text: panel.found.length > 0 ? "Available" : "Searching for devices…"
        }
        Repeater { model: panel.found; delegate: DeviceRow {} }
    }
}
