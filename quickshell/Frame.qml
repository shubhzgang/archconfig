import QtQuick
import QtQuick.Shapes

// The frame around the monitor, drawn as one gradient-filled shape with no outline: the top band
// (holding the bar) and the left band (holding the theme button) are 48px, the right and bottom bands 10px, and the inside edge has rounded
// corners. The stats panel (right) and the calendar panel (left) hang from the top band when open,
// filled like the band, with concave joins where they meet the band and the side edges.
//
// The top-right corner (`statsRect`), where the stats panel hangs, is drawn on its own surfaces
// (shell.qml: the stats panel's piece of the frame, and its shadow), so the stats animation only
// redraws that corner and not the whole screen (the display runs on the integrated GPU). This
// shape leaves that corner square and empty; `statsHole` is the outline those surfaces use.
Item {
    id: frame
    required property var theme
    readonly property int side: 10        // right/bottom band
    readonly property int band: 48        // top band (the bar)
    readonly property int corner: 28      // radius of the screen's inner corners
    property real panelW: 0               // stats panel hanging from the top band, right-aligned (drawn in statsRect)
    property real panelH: 0
    property real leftW: 0                // calendar panel hanging from the top band, left-aligned
    property real leftH: 0
    property real bottomW: 0              // wallpaper picker rising from the bottom band, centered
    property real bottomH: 0
    property real clipW: 0                // clipboard panel sliding out of the left band, in the bottom-left corner; clipY: its top
    property real clipY: 0
    property real clipH: 0

    anchors.fill: parent

    // inside edge of the frame
    readonly property real inL: band      // the left band is as thick as the top one
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
    readonly property bool bottomOpen: bottomH >= 1
    readonly property real bf: Math.min(20, bottomH / 2, bottomW / 2)    // bottom panel's concave joins
    readonly property real br: Math.min(20, bottomH, bottomW / 2)        // its rounded top corners
    readonly property real bl: width / 2 - bottomW / 2                   // its left edge (centered on the screen)
    readonly property real brt: width / 2 + bottomW / 2                  // its right edge

    // the stats panel's corner, [x, y, width, height] on the screen: the widest panel (1000) plus room
    // for its concave join and for the shadows to meet seamlessly at the edges
    readonly property int statsRegionW: 1000 + 60
    readonly property var statsRect: [inR - statsRegionW, inT, statsRegionW, inB - 140 - inT]

    // The free area with only the stats panel's notch (the rest a plain rounded rectangle): what the
    // stats corner's surfaces draw, clipped to statsRect.
    readonly property string statsHole: {
        const L = inL, T = inT, R = inR, B = inB, c = corner
        let d = `M ${L + c} ${T} `
        if (panelOpen)
            d += `L ${px - f} ${T} A ${f} ${f} 0 0 1 ${px} ${T + f} `
               + `L ${px} ${T + panelH - r} A ${r} ${r} 0 0 0 ${px + r} ${T + panelH} `
               + `L ${R - f} ${T + panelH} A ${f} ${f} 0 0 1 ${R} ${T + panelH + f} `
        else
            d += `L ${R - c} ${T} A ${c} ${c} 0 0 1 ${R} ${T + c} `
        return d + `L ${R} ${B - c} A ${c} ${c} 0 0 1 ${R - c} ${B} L ${L + c} ${B} A ${c} ${c} 0 0 1 ${L} ${B - c} `
                 + `L ${L} ${T + c} A ${c} ${c} 0 0 1 ${L + c} ${T} Z`
    }

    // The free area inside the frame, clockwise from the top-left corner. Closed: a rounded
    // rectangle. Open: the top edge turns down the panel's left side, round its bottom, and
    // back out to the right edge. The frame is everything outside it.
    readonly property string hole: holePath(false)
    // the free area without the stats corner: where the screen-wide shadow is kept (the stats
    // corner draws its own)
    readonly property string holeWithoutStats: holePath(true)
    function holePath(withoutStats) {
        const L = inL, T = inT, R = inR, B = inB, c = corner
        // start on the top edge, just right of the left panel (or at the top-left corner)
        let d = `M ${leftOpen ? lx + lf : L + c} ${T} `
        // along the top edge into the (square, empty) top-right corner: the stats corner's own
        // surfaces draw it
        d += `L ${R} ${T} `
        if (withoutStats) {   // round the stats corner instead: across, down its left side, along its bottom
            const sx = statsRect[0], sy = statsRect[1] + statsRect[3]
            d = d.slice(0, d.lastIndexOf("L ")) + `L ${sx} ${T} L ${sx} ${sy} L ${R} ${sy} `
        }
        // down the right edge, along the bottom, up the left edge
        d += `L ${R} ${B - c} A ${c} ${c} 0 0 1 ${R - c} ${B} `
        if (bottomOpen)
            d += `L ${brt + bf} ${B} A ${bf} ${bf} 0 0 1 ${brt} ${B - bf} `
               + `L ${brt} ${B - bottomH + br} A ${br} ${br} 0 0 0 ${brt - br} ${B - bottomH} `
               + `L ${bl + br} ${B - bottomH} A ${br} ${br} 0 0 0 ${bl} ${B - bottomH + br} `
               + `L ${bl} ${B - bf} A ${bf} ${bf} 0 0 1 ${bl - bf} ${B} `
        // along the bottom edge to the left edge, round the clipboard panel in the bottom-left corner if it is out
        if (clipOpen) {
            const y0 = clipY, x1 = L + clipW
            d += `L ${x1 + kf} ${B} A ${kf} ${kf} 0 0 1 ${x1} ${B - kf} `
               + `L ${x1} ${y0 + kr} A ${kr} ${kr} 0 0 0 ${x1 - kr} ${y0} `
               + `L ${L + kf} ${y0} A ${kf} ${kf} 0 0 1 ${L} ${y0 - kf} `
        } else
            d += `L ${L + c} ${B} A ${c} ${c} 0 0 1 ${L} ${B - c} `
        // up to the top-left corner, or round the calendar panel back up to the top edge
        if (leftOpen)
            d += `L ${L} ${T + leftH + lf} A ${lf} ${lf} 0 0 1 ${L + lf} ${T + leftH} `
               + `L ${lx - lr} ${T + leftH} A ${lr} ${lr} 0 0 0 ${lx} ${T + leftH - lr} `
               + `L ${lx} ${T + lf} A ${lf} ${lf} 0 0 1 ${lx + lf} ${T} Z`
        else
            d += `L ${L} ${T + c} A ${c} ${c} 0 0 1 ${L + c} ${T} Z`
        return d
    }

    // (the frame's inner shadow is drawn by FrameShadow.qml, on its own surface below this one)

    // ---- fill: gradient across the screen ----
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: frame.width; y2: 0
                GradientStop { position: 0.0; color: frame.theme.barEnd }
                GradientStop { position: 0.5; color: frame.theme.barStart }
                GradientStop { position: 1.0; color: frame.theme.barEnd }
            }
            PathSvg {
                path: `M -20 -20 L ${frame.width + 20} -20 L ${frame.width + 20} ${frame.height + 20} `
                    + `L -20 ${frame.height + 20} Z ` + frame.hole
            }
        }
    }
}
