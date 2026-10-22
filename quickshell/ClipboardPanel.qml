import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history (cliphist). Enter copies the selected entry back to the clipboard. Images show
// as their cliphist description (no preview).
ListPanel {
    id: panel
    placeholder: "Search clipboard"

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: panel.entries = text.split("\n").filter(l => l !== "").map(l => ({
                line: l, text: l.slice(l.indexOf("\t") + 1).trim()
            }))
        }
    }
    onOpening: lister.running = true
    onPicked: entry => Quickshell.execDetached(["bash", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "_", entry.line])
}
