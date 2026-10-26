import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Screenshots and screen recordings, started from the screenshot panel (ScreenshotPanel.qml) and shown on
// its dock button (the countdown, then a blinking red dot while recording). The panel slides away first;
// then a region or a window is picked (slurp), the delay counts down, and the photo is taken (grim: saved,
// copied and notified) or the recording starts (wf-recorder, with what is playing when audio is on) until
// stop(). Recordings are encoded with NVENC: wf-recorder's VAAPI path hangs on the Radeon 610M, and
// x264 at 4K takes several CPU cores.
Item {
    id: capture
    property int delay: 0           // seconds before the shot (0, 3, 5, 10); saved, as is audio
    property bool audio: true       // record what is playing
    property string phase: "idle"   // idle | waiting | selecting | counting | shooting | recording
    property int remaining: 0       // seconds left while counting
    readonly property bool recording: phase === "recording"

    property string kind            // photo | video
    property string mode            // region | window | screen
    property string geometry        // "x,y wxh" from slurp, "" for the whole screen

    readonly property var delays: [0, 3, 5, 10]
    readonly property string home: Quickshell.env("HOME")

    function cycleDelay() { delay = delays[(delays.indexOf(delay) + 1) % delays.length]; saved.save() }
    function toggleAudio() { audio = !audio; saved.save() }

    function start(k, m) {
        if (phase !== "idle") return
        kind = k; mode = m; geometry = ""
        phase = "waiting"
        settle.restart()
    }
    function stop() {   // ends a recording, or cancels a capture still being set up
        if (phase === "recording") { recorder.signal(2); return }   // SIGINT: wf-recorder finishes the file
        phase = "idle"
        settle.stop(); tick.stop(); shoot.stop()
        selector.running = false
    }

    function stamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") }
    function where() { return geometry ? ["-g", geometry] : ["-o", Hyprland.focusedMonitor?.name ?? ""] }
    function notify(title, body, icon) {
        Quickshell.execDetached(["notify-send", "-a", "Screenshot"].concat(icon ? ["-i", icon] : []).concat([title, body]))
    }

    function countdown() {
        if (delay > 0) { remaining = delay; phase = "counting"; tick.restart() }
        else { phase = "shooting"; shoot.restart() }
    }

    Timer {   // the panel slides away (400ms) and its surface redraws without it
        id: settle
        interval: 600
        onTriggered: {
            if (capture.mode === "screen") { capture.countdown(); return }
            capture.phase = "selecting"
            selector.command = capture.mode === "region" ? ["slurp"] : ["sh", "-c",
                // the windows showing on each monitor (its workspace and any special one over it), to click
                `ws=$(hyprctl monitors -j | jq -c '[.[] | .activeWorkspace.id, .specialWorkspace.id]')
                 hyprctl clients -j | jq -r --argjson ws "$ws" '.[] | select(.mapped and (.hidden | not))
                     | select(.workspace.id as $w | $ws | index($w)) | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"' | slurp -r`]
            selector.running = true
        }
    }

    Process {
        id: selector
        stdout: StdioCollector {
            onStreamFinished: {
                if (capture.phase !== "selecting") return
                const g = text.trim()
                if (!g) { capture.phase = "idle"; return }   // Escape in slurp
                capture.geometry = g
                capture.countdown()
            }
        }
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: if (--capture.remaining <= 0) { tick.stop(); capture.phase = "shooting"; shoot.restart() }
    }

    Timer {   // the countdown on the dock button and slurp's overlay are off the screen by now
        id: shoot
        interval: 150
        onTriggered: {
            if (capture.kind === "photo") {
                const file = `${capture.home}/Pictures/Screenshots/${capture.stamp()}.png`
                Quickshell.execDetached(["sh", "-c", `f=$1; shift
                    mkdir -p "\${f%/*}" && grim "$@" "$f" && wl-copy --type image/png < "$f" &&
                    notify-send -a Screenshot -i "$f" "Screenshot" "Saved to \${f#$HOME/} and copied"`,
                    "sh", file].concat(capture.where()))
                capture.phase = "idle"
            } else {
                recorder.file = `${capture.home}/Videos/Screencasts/${capture.stamp()}.mp4`
                recorder.command = ["sh", "-c", `f=$1; a=$2; shift 2
                    mkdir -p "\${f%/*}" || exit 1
                    [ "$a" = 1 ] && set -- "$@" "--audio=$(pactl get-default-sink).monitor"
                    exec wf-recorder -f "$f" -c h264_nvenc "$@"`,
                    "sh", recorder.file, capture.audio ? "1" : "0"].concat(capture.where())
                recorder.running = true
                capture.phase = "recording"
            }
        }
    }

    Process {
        id: recorder
        property string file
        stderr: StdioCollector { id: recorderLog }
        onExited: code => {
            capture.phase = "idle"
            if (code === 0) capture.notify("Recording saved", "Saved to " + file.replace(capture.home + "/", ""))
            else capture.notify("Recording failed", "wf-recorder exited with " + code + ": "
                                + recorderLog.text.trim().split("\n").slice(-1)[0])
        }
    }

    FileView {
        id: saved
        path: capture.home + "/.cache/quickshell-capture"
        printErrors: false
        function save() { setText(JSON.stringify({ delay: capture.delay, audio: capture.audio })) }
        onLoaded: {
            try {
                const s = JSON.parse(text())
                if (capture.delays.includes(s.delay)) capture.delay = s.delay
                if (typeof s.audio === "boolean") capture.audio = s.audio
            } catch (e) {}
        }
    }
}
