import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Live wallpaper (mpvpaper): a list of YouTube links with their titles and thumbnails, kept in
// hypr/mpvpaper-links.json ([{ title, url, thumb }]). Pick one to play it as the wallpaper
// (hypr/mpvpaper.sh). Paste a link to add it to the list (its title and thumbnail are looked up
// first by hypr/mpvpaper-fetch.sh, and it is only added if the title resolves) or to play it once.
// The trash button, or Shift+Delete, removes the selected one. While one plays, a button floating at the
// bottom right stops it.
ListPanel {
    id: panel
    placeholder: "Search, or paste a link"
    removable: true
    openW: 1300
    rowH: 116
    thumbW: 160
    fontSize: 18
    maxH: 1500
    fitRows: Math.max(entries.length + 2, 10)   // room for the "add" and "play" rows, and never a short panel

    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"
    property var links: []        // saved: { title, url, thumb (relative to hyprDir) }
    property string adding: ""    // the link whose title is being looked up
    property string failed: ""    // the last link whose title couldn't be resolved

    entries: links.map(l => ({ text: l.title, url: l.url, removable: true,
                               thumb: l.thumb ? hyprDir + "/" + l.thumb : "" }))
    extraEntries: {
        if (adding !== "") return [{ text: "Looking up the title…  " + adding, busy: true }]
        if (!typed.startsWith("http")) return []
        const rows = []
        if (failed === typed) rows.push({ text: "Couldn't get a title for this link", busy: true })
        if (!links.some(l => l.url === typed)) rows.push({ text: "Add to the list: " + typed, add: typed, keepOpen: true })
        rows.push({ text: "Play: " + typed, url: typed })
        return rows
    }

    FileView {
        id: file
        path: panel.hyprDir + "/mpvpaper-links.json"
        atomicWrites: true
        onLoaded: {
            try { panel.links = JSON.parse(file.text()) } catch (e) {}
        }
    }
    function save() { file.setText(JSON.stringify(links, null, 2) + "\n") }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const url = panel.adding
                panel.adding = ""
                try {
                    const info = JSON.parse(text)
                    if (!info.title) throw new Error("no title")
                    panel.links = panel.links.concat([{ title: info.title, url: url, thumb: info.thumb }])
                    panel.save()
                    if (panel.typed === url) panel.clearSearch()
                } catch (e) {
                    panel.failed = url
                }
            }
        }
    }

    onOpening: file.reload()
    onPicked: entry => {
        if (entry.busy) return
        if (entry.add) {
            panel.failed = ""
            panel.adding = entry.add
            fetcher.command = ["bash", hyprDir + "/mpvpaper-fetch.sh", entry.add]
            fetcher.running = true
        } else {
            Quickshell.execDetached(["bash", hyprDir + "/mpvpaper.sh", entry.url])
        }
    }
    // Stop: floats over the bottom right of the list while a live wallpaper plays (the list keeps room
    // below its last row, so that row can scroll out from under it)
    listBottomPad: theme.live ? stopButton.height + 12 : 0
    Item {
        id: stopButton
        readonly property bool shown: panel.theme.live
        x: panel.openW - 49 - width   // right-aligned with the rows (16 in from the panel, 27 for the scroll bar, 6 in from the list)
        y: panel.openH - 22 - height
        width: stopRow.implicitWidth + 40
        height: 52
        opacity: panel.contentOpacity
        visible: shown && opacity > 0
        property real lift: stopArea.containsMouse ? 1 : 0   // picked up on hover, as the rows are when selected
        Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            transform: Translate { x: 4 * stopButton.lift; y: -6 * stopButton.lift }
            radius: 10
            color: stopArea.containsMouse ? panel.theme.accent : panel.theme.card
            Behavior on color { ColorAnimation { duration: 150 } }
            RectangularShadow {
                visible: panel.theme.shadows
                anchors.fill: parent; z: -1
                radius: parent.radius; offset: Qt.vector2d(0, 3 + stopButton.lift); blur: 7.2 + 1.4 * stopButton.lift; spread: 1
                color: Qt.rgba(0, 0, 0, (0.45 + 0.15 * stopButton.lift) * parent.color.a)
            }
            Row {
                id: stopRow
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF04DB)   // stop
                    color: panel.theme.dark
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 22
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Stop live wallpaper"
                    color: panel.theme.dark
                    font.family: "CodeNewRoman Nerd Font Mono"
                    font.pixelSize: 17
                }
            }
        }
        MouseArea {
            id: stopArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // (mpvpaper.sh then tells the theme the live wallpaper has ended)
            onClicked: Quickshell.execDetached(["pkill", "-9", "-x", "mpvpaper"])
        }
    }

    onRemoveRequested: entry => {
        const gone = links.find(l => l.url === entry.url)
        links = links.filter(l => l.url !== entry.url)
        save()
        if (gone && gone.thumb) Quickshell.execDetached(["rm", "-f", hyprDir + "/" + gone.thumb])
    }
}
