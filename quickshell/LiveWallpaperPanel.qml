import QtQuick
import Quickshell
import Quickshell.Io

// Live wallpaper (mpvpaper): a list of YouTube links with their titles and thumbnails, kept in
// hypr/mpvpaper-links.json ([{ title, url, thumb }]). Pick one to play it as the wallpaper
// (hypr/mpvpaper.sh). Paste a link to add it to the list (its title and thumbnail are looked up
// first by hypr/mpvpaper-fetch.sh, and it is only added if the title resolves) or to play it once.
// The trash button, or Shift+Delete, removes the selected one.
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
    onRemoveRequested: entry => {
        const gone = links.find(l => l.url === entry.url)
        links = links.filter(l => l.url !== entry.url)
        save()
        if (gone && gone.thumb) Quickshell.execDetached(["rm", "-f", hyprDir + "/" + gone.thumb])
    }
}
