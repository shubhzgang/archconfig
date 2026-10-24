import QtQuick

// The frame around the monitor: the top band (holding the bar) and the left band (holding the dock
// buttons) are 48px, the right and bottom bands 10px, and the inside edge has rounded corners. The
// panels grow out of it, filled like the bands, with concave joins where they meet them.
//
// To keep animations cheap (the display runs on the integrated GPU), the screen is split into
// regions that are drawn on their own surfaces (FrameRegion.qml): the stats corner (top right), the
// left column (calendar, launcher, clipboard, live wallpaper, media), the workspace overview (top
// middle) and the bottom strip (wallpaper picker). A panel's animation then only redraws its own
// region. This item draws the rest of the frame, which never changes shape. Each region draws the
// frame inside its rectangle from an outline with only its own panels' notches (statsHole, leftHole,
// wallHole, topHole).
Item {
    id: frame
    required property var theme
    readonly property int side: 10        // right/bottom band
    readonly property int band: 48        // top and left bands
    readonly property int corner: 28      // radius of the screen's inner corners
    property real panelW: 0               // stats panel hanging from the top band, right-aligned
    property real panelH: 0
    property real leftW: 0                // calendar/launcher hanging from the top band, left-aligned
    property real leftH: 0
    property real bottomW: 0              // wallpaper picker rising from the bottom band, centered
    property real bottomH: 0
    property real clipW: 0                // clipboard (etc.) panel out of the left band, bottom-left; clipY: its top
    property real clipY: 0
    property real clipH: 0
    property real midW: 0                 // media panel out of the left band, in the middle; midY: its top
    property real midY: 0
    property real midH: 0
    property real wallMaxW: 0             // the wallpaper picker's full size (its region's size)
    property real wallMaxH: 0
    property real topW: 0                 // workspace overview hanging from the top band, centered
    property real topH: 0
    property real topMaxW: 0              // its largest size (its region's size)
    property real topMaxH: 0

    anchors.fill: parent

    // inside edge of the frame
    readonly property real inL: band
    readonly property real inT: band
    readonly property real inR: width - side
    readonly property real inB: height - side
    readonly property bool panelOpen: panelH >= 1
    readonly property real f: Math.min(20, panelH / 2, panelW / 2)       // concave joins
    readonly property real r: Math.min(20, panelH, panelW / 2)           // panel's rounded bottom-left corner
    readonly property real px: inR - panelW                              // panel's left edge
    readonly property bool leftOpen: leftH >= 1
    readonly property real lf: Math.min(20, leftH / 2, leftW / 2)        // left panel's concave joins
    readonly property real lr: Math.min(20, leftH, leftW / 2)            // its rounded bottom-right corner
    readonly property real lx: inL + leftW                               // left panel's right edge
    readonly property bool clipOpen: clipW >= 1
    readonly property real kf: Math.min(20, clipW / 2, clipH / 2)        // clipboard panel's concave joins
    readonly property real kr: Math.min(20, clipW / 2, clipH / 2)        // its rounded top-right corner
    readonly property bool midOpen: midW >= 1
    readonly property real mf: Math.min(20, midW / 2, midH / 2)          // media panel's concave joins
    readonly property real mr: Math.min(20, midW / 2, midH / 2)          // its rounded right corners
    readonly property bool bottomOpen: bottomH >= 1
    readonly property real bf: Math.min(20, bottomH / 2, bottomW / 2)    // bottom panel's concave joins
    readonly property real br: Math.min(20, bottomH, bottomW / 2)        // its rounded top corners
    readonly property real bl: width / 2 - bottomW / 2                   // its left edge (centered on the screen)
    readonly property real brt: width / 2 + bottomW / 2                  // its right edge
    readonly property bool topOpen: topH >= 1
    readonly property real tf: Math.min(20, topH / 2, topW / 2)          // workspace overview's concave joins
    readonly property real tr: Math.min(20, topH, topW / 2)              // its rounded bottom corners
    readonly property real tl: width / 2 - topW / 2                      // its left edge (centered on the screen)
    readonly property real trt: width / 2 + topW / 2                     // its right edge

    // ---- regions, [x, y, w, h] on the screen ----
    // each is its panels' largest size plus 20px for the concave joins and 40px for the shadows to
    // meet seamlessly at the edges. They overlap where the left column meets the bottom strip, and
    // where the workspace overview's (wide, along the top) meets the left column's and the stats corner's.
    // Each is 1px larger all round: the glass edge (FrameFill.qml) is a 1px line centred on the
    // inside edge, so half of it falls just outside a region that starts at that edge, and it would
    // be left there, drawn by the rest of the frame, when a panel opens out of that edge.
    function grown(r) { return [r[0] - 1, r[1] - 1, r[2] + 2, r[3] + 2] }
    readonly property var statsRect: grown([inR - 1060, inT, 1060, inB - 360 - inT])
    readonly property var leftRect: grown([inL, inT, 1300 + 60, inB - inT])
    readonly property var wallRect: {
        const w = wallMaxW + 120, h = wallMaxH + 60
        return grown([Math.round(width / 2 - w / 2), inB - h, Math.round(w), h])
    }
    readonly property var topRect: {
        const w = topMaxW + 120, h = topMaxH + 60
        return grown([Math.round(width / 2 - w / 2), inT, Math.round(w), h])
    }
    readonly property var overlap: intersect(leftRect, wallRect)
    // which one draws the frame and its shadow where they overlap: the picker or the overview while
    // it is out, else the left column and the stats corner
    readonly property var leftKeep: subtract([leftRect], [bottomOpen ? overlap : null, topOpen ? topRect : null].filter(r => r))
    readonly property var wallKeep: !bottomOpen && overlap ? subtract([wallRect], [overlap]) : [wallRect]
    readonly property var statsKeep: topOpen ? subtract([statsRect], [topRect]) : [statsRect]
    readonly property var topKeep: topOpen ? [topRect] : subtract([topRect], [leftRect, statsRect])
    // everything else is drawn here
    readonly property var baseKeep: subtract([[0, 0, width, height]], [statsRect, leftRect, wallRect, topRect])

    function intersect(a, b) {
        const x0 = Math.max(a[0], b[0]), y0 = Math.max(a[1], b[1])
        const x1 = Math.min(a[0] + a[2], b[0] + b[2]), y1 = Math.min(a[1] + a[3], b[1] + b[3])
        return x1 > x0 && y1 > y0 ? [x0, y0, x1 - x0, y1 - y0] : null
    }
    function subtract(rects, holes) {   // rects minus holes, as non-overlapping rectangles
        for (const h of holes) {
            const out = []
            for (const r of rects) {
                const i = intersect(r, h)
                if (!i) { out.push(r); continue }
                const rx1 = r[0] + r[2], ry1 = r[1] + r[3], ix1 = i[0] + i[2], iy1 = i[1] + i[3]
                if (i[1] > r[1]) out.push([r[0], r[1], r[2], i[1] - r[1]])           // above
                if (iy1 < ry1) out.push([r[0], iy1, r[2], ry1 - iy1])               // below
                if (i[0] > r[0]) out.push([r[0], i[1], i[0] - r[0], i[3]])          // left
                if (ix1 < rx1) out.push([ix1, i[1], rx1 - ix1, i[3]])               // right
            }
            rects = out
        }
        return rects
    }

    // ---- outlines of the free area inside the frame ----
    // Clockwise from the top-left corner: a rounded rectangle, with the notches of the panels asked
    // for. The frame is everything outside it.
    function holePath(stats, left, bottom, clip, mid, top) {
        const L = inL, T = inT, R = inR, B = inB, c = corner
        const lOpen = left && leftOpen, sOpen = stats && panelOpen, bOpen = bottom && bottomOpen, cOpen = clip && clipOpen
        const mOpen = mid && midOpen, tOpen = top && topOpen
        // start on the top edge, just right of the left panel (or at the top-left corner)
        let d = `M ${lOpen ? lx + lf : L + c} ${T} `
        // round the workspace overview in the middle of the top edge
        if (tOpen)
            d += `L ${tl - tf} ${T} A ${tf} ${tf} 0 0 1 ${tl} ${T + tf} `
               + `L ${tl} ${T + topH - tr} A ${tr} ${tr} 0 0 0 ${tl + tr} ${T + topH} `
               + `L ${trt - tr} ${T + topH} A ${tr} ${tr} 0 0 0 ${trt} ${T + topH - tr} `
               + `L ${trt} ${T + tf} A ${tf} ${tf} 0 0 1 ${trt + tf} ${T} `
        // along the top edge, then down round the stats panel, or round the top-right corner
        if (sOpen)
            d += `L ${px - f} ${T} A ${f} ${f} 0 0 1 ${px} ${T + f} `
               + `L ${px} ${T + panelH - r} A ${r} ${r} 0 0 0 ${px + r} ${T + panelH} `
               + `L ${R - f} ${T + panelH} A ${f} ${f} 0 0 1 ${R} ${T + panelH + f} `
        else
            d += `L ${R - c} ${T} A ${c} ${c} 0 0 1 ${R} ${T + c} `
        // down the right edge, along the bottom (round the wallpaper picker)
        d += `L ${R} ${B - c} A ${c} ${c} 0 0 1 ${R - c} ${B} `
        if (bOpen)
            d += `L ${brt + bf} ${B} A ${bf} ${bf} 0 0 1 ${brt} ${B - bf} `
               + `L ${brt} ${B - bottomH + br} A ${br} ${br} 0 0 0 ${brt - br} ${B - bottomH} `
               + `L ${bl + br} ${B - bottomH} A ${br} ${br} 0 0 0 ${bl} ${B - bottomH + br} `
               + `L ${bl} ${B - bf} A ${bf} ${bf} 0 0 1 ${bl - bf} ${B} `
        // to the left edge, round the clipboard panel in the bottom-left corner if it is out
        if (cOpen) {
            const y0 = clipY, x1 = L + clipW
            d += `L ${x1 + kf} ${B} A ${kf} ${kf} 0 0 1 ${x1} ${B - kf} `
               + `L ${x1} ${y0 + kr} A ${kr} ${kr} 0 0 0 ${x1 - kr} ${y0} `
               + `L ${L + kf} ${y0} A ${kf} ${kf} 0 0 1 ${L} ${y0 - kf} `
        } else
            d += `L ${L + c} ${B} A ${c} ${c} 0 0 1 ${L} ${B - c} `
        // up the left edge, round the media panel in the middle if it is out
        if (mOpen) {
            const y0 = midY, y1 = midY + midH, x1 = L + midW
            d += `L ${L} ${y1 + mf} A ${mf} ${mf} 0 0 1 ${L + mf} ${y1} `
               + `L ${x1 - mr} ${y1} A ${mr} ${mr} 0 0 0 ${x1} ${y1 - mr} `
               + `L ${x1} ${y0 + mr} A ${mr} ${mr} 0 0 0 ${x1 - mr} ${y0} `
               + `L ${L + mf} ${y0} A ${mf} ${mf} 0 0 1 ${L} ${y0 - mf} `
        }
        // up to the top-left corner, or round the calendar panel back up to the top edge
        if (lOpen)
            d += `L ${L} ${T + leftH + lf} A ${lf} ${lf} 0 0 1 ${L + lf} ${T + leftH} `
               + `L ${lx - lr} ${T + leftH} A ${lr} ${lr} 0 0 0 ${lx} ${T + leftH - lr} `
               + `L ${lx} ${T + lf} A ${lf} ${lf} 0 0 1 ${lx + lf} ${T} Z`
        else
            d += `L ${L} ${T + c} A ${c} ${c} 0 0 1 ${L + c} ${T} Z`
        return d
    }
    readonly property string plainHole: holePath(false, false, false, false)
    readonly property string statsHole: holePath(true, false, false, false)
    readonly property string leftHole: holePath(false, true, false, true, true)
    readonly property string wallHole: holePath(false, false, true, false)
    readonly property string topHole: holePath(false, false, false, false, false, true)

    // ---- the frame outside the regions (it never changes shape) ----
    // (its inner shadow is drawn by FrameShadow.qml, on its own surface below this one)
    Repeater {
        model: frame.baseKeep
        delegate: FrameFill {
            required property var modelData
            theme: frame.theme
            rect: modelData
            hole: frame.plainHole
        }
    }
}
