import QtQuick
import Quickshell.Io

// A JSON file that is re-read every second while `active` (the sampler replaces its files atomically).
// `value` only changes when the file's text did, so an unchanged file doesn't make everything bound to
// it re-evaluate (and redraw).
Item {
    id: root
    property string path
    property var value: ({})
    property int interval: 1000
    property bool active: true
    property string lastText: ""

    FileView {
        id: fv
        path: root.path
        onLoaded: {
            const text = fv.text()
            if (text === root.lastText) return
            root.lastText = text
            try { root.value = JSON.parse(text) } catch (e) {}
        }
    }
    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: fv.reload()
    }
}
