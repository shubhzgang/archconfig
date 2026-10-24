import QtQuick
import QtQml
import Quickshell.Services.Mpris

// The media player shown in the left band (MediaStrip.qml) and the media panel (MediaPanel.qml): the
// one that most recently started playing (so music or a video takes over from a live wallpaper, which
// plays all the time), else any one playing, else the one that last started, else any. playerctld is left
// out: it stands in for the others, so its track would be the same one again.
Item {
    id: root
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property var last: null
    readonly property var player: {
        if (players.includes(last) && last.isPlaying) return last
        return players.find(p => p.isPlaying) ?? (players.includes(last) ? last : players[0] ?? null)
    }
    Instantiator {   // a player that starts playing becomes the one shown
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { if (modelData.isPlaying) root.last = modelData }
        }
    }

    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property bool playing: player?.isPlaying ?? false

    function time(s) {   // seconds as m:ss, or h:mm:ss
        s = Math.max(0, Math.floor(s))
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, ss = String(s % 60).padStart(2, "0")
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`
    }
}
