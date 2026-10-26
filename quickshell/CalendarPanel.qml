import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell

// Calendar that grows out of the top band at the left, drawn by the frame like the stats panel.
// The bar's own items stay visible above it; clicking the clock toggles it.
Item {
    id: panel
    required property var theme
    property bool open: false
    signal toggle()

    readonly property int band: 48
    readonly property real openW: 396
    readonly property real openH: card.implicitHeight + 48     // 24px of panel around the card, for its shadow
    property real panelW: 0
    property real panelH: 0
    property int monthShift: 0            // months away from the current one

    anchors { top: parent.top; left: parent.left; leftMargin: band }
    width: panelW
    height: band + panelH
    clip: true

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth() + monthShift, 1)
    onOpenChanged: if (open) monthShift = 0

    // Same shape of animation as the stats panel: eases out when opening, eases in when closing.
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

    // click anywhere on the panel (outside the buttons) to close it
    MouseArea {
        anchors.fill: parent
        enabled: panel.open
        onClicked: panel.toggle()
    }

    Item {
        id: content
        // The card sits 24px in from the panel's edge (4px margin here + 20px inset below): room for
        // the card's shadow, which the clip would otherwise cut off
        // (a fixed size, so nothing reflows while the panel grows; the panel clips it meanwhile)
        x: 4; y: panel.band + 4
        width: panel.openW - 8
        height: panel.openH - 8
        clip: true
        opacity: panel.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {   // content fades in once the shape has (nearly) finished growing
            SequentialAnimation {
                PauseAnimation { duration: panel.open ? 300 : 0 }
                NumberAnimation { duration: panel.open ? 150 : 100 }
            }
        }

        // Shadow: 20% black, grown 8px past the card so it stays dark for 8px, then blurred so it fades.
        RectangularShadow {
            visible: panel.theme.shadows
            x: card.x - 8; y: card.y - 8 + 3
            width: card.width + 16; height: card.height + 16
            radius: card.radius + 8; blur: 7.2; spread: 1
            color: "#33000000"
        }

        Card {
            id: card
            theme: panel.theme
            shadowColor: "transparent"   // the shadow above replaces the card's own
            x: 20
            y: 20
            width: parent.width - 40

            // month title with previous / next buttons
            Item {
                width: parent.width
                height: 34
                component NavButton: Rectangle {
                    property string label
                    signal clicked()
                    width: 34; height: 30; radius: 8
                    color: area.containsMouse ? Qt.rgba(0, 0, 0, 0.08) : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(panel.theme.dark.r, panel.theme.dark.g, panel.theme.dark.b, 0.35)
                    Text {
                        anchors.centerIn: parent
                        text: parent.label
                        color: panel.theme.dark
                        font.family: "CodeNewRoman Nerd Font Mono"; font.pixelSize: 18
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.clicked()
                    }
                }
                NavButton { anchors.left: parent.left; label: "‹"; onClicked: panel.monthShift-- }
                NavButton { anchors.right: parent.right; label: "›"; onClicked: panel.monthShift++ }
                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDate(panel.shown, "MMMM yyyy")
                    color: panel.theme.dark
                    font.family: "CodeNewRoman Nerd Font Mono"; font.pixelSize: 19; font.bold: true
                    MouseArea {   // click the title to jump back to the current month
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.monthShift = 0
                    }
                }
            }

            DayOfWeekRow {
                width: parent.width
                locale: Qt.locale()
                delegate: Text {
                    required property var model
                    text: model.shortName
                    color: Qt.rgba(panel.theme.dark.r, panel.theme.dark.g, panel.theme.dark.b, 0.6)
                    font.family: "CodeNewRoman Nerd Font Mono"; font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            MonthGrid {
                id: grid
                width: parent.width
                height: 6 * 40
                month: panel.shown.getMonth()
                year: panel.shown.getFullYear()
                locale: Qt.locale()
                delegate: Item {
                    required property var model
                    Rectangle {   // today
                        anchors.centerIn: parent
                        width: 34; height: 34; radius: 17
                        visible: model.today
                        color: panel.theme.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        opacity: model.month === grid.month ? 1 : 0.35
                        color: model.today ? "white" : panel.theme.dark
                        font.family: "CodeNewRoman Nerd Font Mono"; font.pixelSize: 16
                        font.bold: model.today
                    }
                }
            }
        }
    }
}
