import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Top-left section, replicating waybar's: notifications button, clock (calendar on hover),
// pending pacman updates, tray, bluetooth and network.
Item {
    id: section
    required property var theme
    required property var win           // the PanelWindow (tray menus anchor to it)
    readonly property alias tipRect: tip
    readonly property alias calendarRect: calendar

    anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 14 + 8 }   // inside the frame's top band
    height: 39
    width: row.implicitWidth

    // ---- data ----
    SystemClock { id: clock; precision: SystemClock.Seconds }
    property int monthShift: 0           // calendar: left click = next month, right click = previous
    property string pacmanCount: "?"

    Process {
        id: pacmanCheck
        command: ["sh", "-c", "checkupdates | wc -l"]
        stdout: StdioCollector { onStreamFinished: section.pacmanCount = text.trim() || "0" }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: pacmanCheck.running = true }
    Process {
        id: pacmanUpdate
        command: ["kitty", "sh", "-c", "yay -Syu; echo Done - Press enter to exit; read"]
        onExited: pacmanCheck.running = true
    }
    Process { id: swaync; command: ["swaync-client", "-t", "-sw"] }
    Process { id: blueman; command: ["blueman-manager"] }
    Process { id: nmtui; command: ["kitty", "nmtui"] }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property var netDevice: {
        const devs = Networking.devices.values
        for (const d of devs) if (d.connected) return d
        return null
    }
    readonly property bool netWifi: netDevice !== null && netDevice.type === DeviceType.Wifi
    readonly property var wifiNet: {
        if (!netWifi) return null
        for (const n of netDevice.networks.values) if (n.connected) return n
        return null
    }

    // ---- tooltip shared by the modules ----
    property string tipText: ""
    property Item tipFor: null
    Rectangle {
        id: tip
        readonly property bool shown: section.tipFor !== null && section.tipText !== ""
        x: shown ? Math.max(0, Math.min(section.tipFor.mapToItem(section, 0, 0).x, section.width - width)) : 0
        y: section.height + 8
        width: shown ? tipLabel.implicitWidth + 24 : 0
        height: shown ? tipLabel.implicitHeight + 16 : 0
        visible: shown
        radius: 8
        color: section.theme.barStart
        border.width: 1
        border.color: section.theme.accent
        Text {
            id: tipLabel
            anchors.centerIn: parent
            text: section.tipText
            color: section.theme.ink
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
        }
    }

    // ---- calendar (hover over the clock) ----
    Rectangle {
        id: calendar
        readonly property bool shown: clockMod.hovered
        readonly property date shownDate: new Date(clock.date.getFullYear(), clock.date.getMonth() + section.monthShift, 1)
        x: row.x + clockMod.x
        y: section.height + 8
        width: shown ? 300 : 0
        height: shown ? cal.implicitHeight + 28 : 0
        visible: shown
        radius: 10
        color: section.theme.barStart
        border.width: 2
        border.color: section.theme.accent
        clip: true
        Column {
            id: cal
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 6
            Text {
                text: Qt.formatDate(calendar.shownDate, "MMMM yyyy")
                color: section.theme.ink
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 16
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            DayOfWeekRow {
                width: parent.width
                locale: Qt.locale()
                delegate: Text {
                    text: model.shortName
                    color: section.theme.hover
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            MonthGrid {
                id: grid
                width: parent.width
                month: calendar.shownDate.getMonth()
                year: calendar.shownDate.getFullYear()
                locale: Qt.locale()
                delegate: Text {
                    required property var model
                    text: model.day
                    opacity: model.month === grid.month ? 1 : 0.35
                    color: model.today && section.monthShift === 0 ? "#E5534B" : section.theme.ink
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 14
                    font.bold: model.today && section.monthShift === 0
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // ---- the modules ----
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Mod {
            theme: section.theme
            text: ""
            onClicked: swaync.running = true
        }
        Mod {
            id: clockMod
            theme: section.theme
            text: Qt.formatDateTime(clock.date, "hh:mm:ss AP") + " "
            onHoveredChanged: if (!hovered) section.monthShift = 0
            onClicked: mouse => section.monthShift += mouse.button === Qt.RightButton ? -1 : 1
        }
        Mod {
            theme: section.theme
            text: String.fromCodePoint(0xf0162) + " " + section.pacmanCount
            onClicked: pacmanUpdate.running = true
        }
        Row {   // tray
            spacing: 10
            leftPadding: 5
            rightPadding: 5
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: trayItem
                    required property var modelData
                    width: 14
                    height: 14
                    IconImage { anchors.fill: parent; source: trayItem.modelData.icon }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                trayItem.modelData.secondaryActivate()
                            } else if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                const p = trayItem.mapToItem(null, 0, trayItem.height + 4)
                                if (trayItem.modelData.hasMenu) trayItem.modelData.display(section.win, p.x, p.y)
                            } else {
                                trayItem.modelData.activate()
                            }
                        }
                    }
                }
            }
        }
        Mod {
            id: btMod
            theme: section.theme
            text: String.fromCodePoint(section.btAdapter && section.btAdapter.enabled ? 0xf00af : 0xf00b2)
            onClicked: mouse => { if (mouse.button === Qt.RightButton) blueman.running = true }
            onHoveredChanged: {
                if (hovered) {
                    section.tipFor = btMod
                    const a = section.btAdapter
                    if (!a) { section.tipText = "No bluetooth controller"; return }
                    let t = a.name + "\n\n" + section.btConnected.length + " connected"
                    for (const d of section.btConnected)
                        t += "\n" + d.name + (d.batteryAvailable ? "  " + Math.round(d.battery * (d.battery <= 1 ? 100 : 1)) + "%" : "")
                    section.tipText = t
                } else if (section.tipFor === btMod) { section.tipFor = null }
            }
        }
        Mod {
            id: netMod
            theme: section.theme
            text: section.netDevice === null ? "" : (section.netWifi ? "" : "")
            onClicked: nmtui.running = true
            onHoveredChanged: {
                if (hovered) {
                    section.tipFor = netMod
                    if (section.netDevice === null) section.tipText = "Error"
                    else if (section.netWifi) {
                        const s = section.wifiNet ? section.wifiNet.signalStrength : 0
                        section.tipText = (section.wifiNet ? section.wifiNet.name : section.netDevice.name) + " (" + Math.round(s <= 1 ? s * 100 : s) + "%)"
                    } else section.tipText = section.netDevice.name
                } else if (section.tipFor === netMod) { section.tipFor = null }
            }
        }
    }
}
