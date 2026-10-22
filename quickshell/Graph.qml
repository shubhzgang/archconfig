import QtQuick

// Line graph with faint grid; one shared y-axis from zero. series: [{values: [], color: "#hex"}]
Canvas {
    id: root
    property var series: []
    property real ymax: 100
    property int points: 120
    property real interval: 1       // seconds between samples (for the time-ago labels)
    readonly property int labelH: 16  // strip under the plot for the time-ago labels
    property color gridColor: "#26000000"
    property color labelColor: "#80101820"
    property string maxLabel: ""
    // mirrored (network): series[0] grows up from the center line on its own scale (ymax),
    // series[1] grows down on its scale (ymax2); each scale is labeled at its outer edge.
    property bool mirrored: false
    property real ymax2: 100
    property string maxLabel2: ""

    onSeriesChanged: requestPaint()
    onYmaxChanged: requestPaint()
    onYmax2Changed: requestPaint()
    onIntervalChanged: requestPaint()
    onPointsChanged: requestPaint()
    onMirroredChanged: requestPaint()
    onGridColorChanged: requestPaint()
    onLabelColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const w = width, h = height - labelH
        const step = w / (points - 1)
        const quarter = Math.max(Math.floor(points / 4), 1)   // guides at 1/4, 2/4, 3/4 of the window
        const mid = Math.round(h / 2) + 0.5
        ctx.strokeStyle = gridColor
        ctx.lineWidth = 1
        const lines = mirrored ? [0.5, mid, h - 0.5] : [0.5, Math.round(h / 2) + 0.5, h - 0.5]
        for (const y of lines) {
            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
        }
        const ago = sec => {
            sec = Math.round(sec)
            const m = Math.floor(sec / 60), r = sec % 60
            return m ? "-" + m + "m" + (r ? " " + (r < 10 ? "0" : "") + r + "s" : "") : "-" + r + "s"
        }
        ctx.font = "12px sans-serif"
        ctx.textAlign = "center"
        for (let k = quarter; k < points; k += quarter) {
            const x = Math.round(w - k * step) + 0.5
            ctx.strokeStyle = gridColor
            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke()
            ctx.fillStyle = labelColor
            ctx.fillText(ago(k * interval), x, h + 13)
        }
        ctx.textAlign = "left"
        const rgba = (c, a) => Qt.rgba(Qt.color(c).r, Qt.color(c).g, Qt.color(c).b, a)
        for (let k = 0; k < series.length; k++) {
            const s = series[k]
            const v = s.values
            if (!v || v.length < 2) continue
            const n = v.length
            // base line and direction: plain graphs grow up from the bottom; mirrored ones from the middle
            const base = mirrored ? mid : h - 1
            const dir = mirrored && k === 1 ? 1 : -1
            const span = mirrored ? (h / 2 - 1) : (h - 2)
            const scale = mirrored && k === 1 ? ymax2 : ymax
            const px = i => w - (n - 1 - i) * step
            const py = val => base + dir * span * Math.min(val / scale, 1)
            ctx.beginPath()
            ctx.moveTo(px(0), py(v[0]))
            for (let i = 1; i < n; i++) ctx.lineTo(px(i), py(v[i]))
            ctx.strokeStyle = s.color
            ctx.lineWidth = 2
            ctx.lineJoin = "round"
            ctx.stroke()
            ctx.lineTo(px(n - 1), base); ctx.lineTo(px(0), base); ctx.closePath()
            const far = base + dir * span
            const g = ctx.createLinearGradient(0, far, 0, base)
            g.addColorStop(0, rgba(s.color, 0.35))
            g.addColorStop(1, rgba(s.color, 0.02))
            ctx.fillStyle = g
            ctx.fill()
        }
        ctx.fillStyle = labelColor
        ctx.font = "12px sans-serif"
        if (maxLabel) ctx.fillText(maxLabel, 4, 14)
        if (mirrored && maxLabel2) ctx.fillText(maxLabel2, 4, h - 6)
    }
}
