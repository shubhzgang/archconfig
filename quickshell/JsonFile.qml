import QtQuick
import Quickshell.Io

// A JSON file that is re-read every second (the sampler replaces its files atomically).
Item {
    id: root
    property string path
    property var value: ({})
    property int interval: 1000

    FileView {
        id: fv
        path: root.path
        onLoaded: {
            try { root.value = JSON.parse(fv.text()) } catch (e) {}
        }
    }
    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fv.reload()
    }
}
