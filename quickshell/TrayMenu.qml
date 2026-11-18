import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// A tray icon's menu (LeftSection.qml), drawn in the theme instead of by Qt: below the top band at the
// icon, in the bar's color with an accent edge like the bar's tooltips; the selected entry is filled
// with the accent, as a selected card. Up/Down or the mouse select (hovering selects), Enter or a
// click picks; a submenu opens in its place, with a way back at the top (Left or Backspace too).
// Escape, or a click outside, closes it.
PanelWindow {
    id: menu
    required property var theme
    property var item: null          // the tray item whose menu this is
    property real atX: 0             // the icon's left edge on the screen
    property bool open: false
    signal close()

    readonly property int band: 48   // the frame's top band (Frame.qml)
    readonly property int pad: 24    // room round the menu for its shadow
    property var stack: []           // the submenus opened, the innermost last

    anchors { top: true; left: true }
    margins { top: band + 4 - pad; left: Math.max(0, atX - 8 - pad) }
    implicitWidth: card.width + 2 * pad
    implicitHeight: card.height + 2 * pad
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-traymenu"
    // the keyboard exclusively for a moment when it opens, then on demand (as the panels' regions do)
    WlrLayershell.keyboardFocus: grab.running ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    visible: open && item !== null
    Timer { id: grab; interval: 200 }
    onVisibleChanged: if (visible) { stack = []; grab.restart(); keys.forceActiveFocus() }
    onItemChanged: stack = []

    // ---- the entries ----
    QsMenuOpener {
        id: opener
        menu: menu.stack.length ? menu.stack[menu.stack.length - 1] : (menu.item?.menu ?? null)
    }
    // a submenu starts with the way back
    readonly property var rows: (stack.length ? [{ back: true }] : []).concat((opener.children?.values ?? []).map(e => ({ entry: e })))
    function usable(row) { return !!row && (row.back || (!row.entry.isSeparator && row.entry.enabled)) }
    function label(row) {   // without the underscores that mark keyboard accelerators ("__" is a "_")
        if (row.back) return stack[stack.length - 1].text.replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_")
        return row.entry.text.replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_")
    }
    function lead(row) {   // a glyph before the label: the way back, a check box or a radio button
        if (row.back) return 0xF0141
        const e = row.entry, on = e.checkState === Qt.Checked
        if (e.buttonType === QsMenuButtonType.CheckBox) return on ? 0xF0132 : 0xF0131
        if (e.buttonType === QsMenuButtonType.RadioButton) return on ? 0xF043E : 0xF043D
        return 0
    }
    readonly property bool hasLead: rows.some(r => !r.back ? (!r.entry.isSeparator && (lead(r) || r.entry.icon)) : true)
    readonly property bool hasSub: rows.some(r => !r.back && r.entry.hasChildren)

    // ---- selection: the first usable entry (rather than the way back) when the entries change ----
    property int sel: -1
    function first() {
        if (!rows) return -1   // (not made yet: the stack is set as the menu is created)
        const i = rows.findIndex(r => !r.back && usable(r))
        return i >= 0 ? i : rows.findIndex(r => usable(r))
    }
    onRowsChanged: if (!usable(rows[sel])) sel = first()
    onStackChanged: sel = first()
    function step(by) {
        for (let i = sel + by; i >= 0 && i < rows.length; i += by)
            if (usable(rows[i])) { sel = i; return }
    }
    function pick(row) {
        if (!usable(row)) return
        if (row.back) { stack = stack.slice(0, -1); return }
        if (row.entry.hasChildren) { stack = stack.concat([row.entry]); return }
        row.entry.triggered()
        menu.close()
    }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: menu.close()
        Keys.onUpPressed: menu.step(-1)
        Keys.onDownPressed: menu.step(1)
        Keys.onReturnPressed: menu.pick(menu.rows[menu.sel])
        Keys.onEnterPressed: menu.pick(menu.rows[menu.sel])
        Keys.onRightPressed: { const r = menu.rows[menu.sel]; if (r && !r.back && r.entry.hasChildren) menu.pick(r) }
        Keys.onLeftPressed: if (menu.stack.length) menu.stack = menu.stack.slice(0, -1)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace && menu.stack.length) { menu.stack = menu.stack.slice(0, -1); event.accepted = true }
        }
    }

    TextMetrics { id: charW; font.family: "CodeNewRoman Nerd Font Mono"; font.pixelSize: 15; text: "0" }

    Rectangle {
        id: card
        x: menu.pad; y: menu.pad
        // as wide as the longest label (the font is monospaced), with room for the glyphs
        width: Math.min(480, Math.max(200, 12 + 20 + (menu.hasLead ? 26 : 0) + (menu.hasSub ? 26 : 0)
                                           + charW.advanceWidth * Math.max(0, ...menu.rows.map(r => r.back || !r.entry.isSeparator ? menu.label(r).length : 0))))
        height: column.implicitHeight + 12
        radius: 10
        color: menu.theme.barStart
        border.width: 1
        border.color: menu.theme.accent
        RectangularShadow {
            visible: menu.theme.shadows
            anchors.fill: parent; z: -1
            radius: parent.radius; offset: Qt.vector2d(0, 3); blur: 6.5; spread: 1
            color: Qt.rgba(0, 0, 0, 0.33 * parent.color.a)
        }

        Column {
            id: column
            x: 6; y: 6
            width: parent.width - 12
            Repeater {
                model: menu.rows
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool separator: !modelData.back && modelData.entry.isSeparator
                    readonly property bool usable: menu.usable(modelData)
                    readonly property bool selected: index === menu.sel
                    width: column.width
                    height: separator ? 9 : 34

                    Rectangle {   // a separator
                        visible: row.separator
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Qt.rgba(menu.theme.ink.r, menu.theme.ink.g, menu.theme.ink.b, 0.2)
                    }
                    Rectangle {   // the selection
                        visible: !row.separator
                        anchors.fill: parent
                        radius: 8
                        color: menu.theme.accent
                        opacity: row.selected ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    Row {
                        visible: !row.separator
                        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: menu.hasSub ? 32 : 10
                                  verticalCenter: parent.verticalCenter }
                        spacing: 8
                        opacity: row.usable ? 1 : 0.4
                        Item {   // the glyph, or the entry's icon
                            visible: menu.hasLead
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18
                            readonly property int glyph: row.separator ? 0 : menu.lead(row.modelData)
                            Text {
                                visible: parent.glyph !== 0
                                anchors.centerIn: parent
                                text: parent.glyph ? String.fromCodePoint(parent.glyph) : ""
                                color: row.selected ? menu.theme.dark : menu.theme.ink
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 17
                            }
                            IconImage {
                                visible: parent.glyph === 0 && source != ""
                                anchors.fill: parent
                                source: row.modelData.back || row.separator ? "" : row.modelData.entry.icon
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (menu.hasLead ? 26 : 0)
                            elide: Text.ElideRight
                            text: row.separator ? "" : menu.label(row.modelData)
                            color: row.selected ? menu.theme.dark : menu.theme.ink
                            font.family: "CodeNewRoman Nerd Font Mono"
                            font.pixelSize: 15
                        }
                    }
                    Text {   // a submenu
                        visible: !row.separator && !row.modelData.back && row.modelData.entry.hasChildren
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: String.fromCodePoint(0xF0142)
                        color: row.selected ? menu.theme.dark : menu.theme.ink
                        opacity: row.usable ? 1 : 0.4
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 17
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.separator
                        hoverEnabled: true
                        cursorShape: row.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPositionChanged: if (row.usable) menu.sel = row.index   // hovering selects
                        onClicked: menu.pick(row.modelData)
                    }
                }
            }
        }
    }
}
