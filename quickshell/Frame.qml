import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The frame around the monitor, drawn as one gradient-filled shape with no outline: the top band
// (holding the bar) is 56px, the left, right and bottom bands 3px, and the inside edge has rounded
// corners. The stats panel (right) and the calendar panel (left) hang from the top band when open,
// filled like the band, with concave joins where they meet the band and the side edges.
Item {
    id: frame
    required property var theme
    readonly property int side: 10        // left/right/bottom band
    readonly property int band: 56        // top band (the bar)
    readonly property int corner: 28      // radius of the screen's inner corners
    property real panelW: 0               // stats panel hanging from the top band, right-aligned
    property real panelH: 0
    property real leftW: 0                // calendar panel hanging from the top band, left-aligned
    property real leftH: 0
    property real bottomW: 0              // wallpaper picker rising from the bottom band, centered
    property real bottomH: 0

    anchors.fill: parent

    // inside edge of the frame
    readonly property real inL: side
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
    readonly property bool bottomOpen: bottomH >= 1
    readonly property real bf: Math.min(20, bottomH / 2, bottomW / 2)    // bottom panel's concave joins
    readonly property real br: Math.min(20, bottomH, bottomW / 2)        // its rounded top corners
    readonly property real bl: (inL + inR) / 2 - bottomW / 2             // its left edge
    readonly property real brt: (inL + inR) / 2 + bottomW / 2            // its right edge

    // The free area inside the frame, clockwise from the top-left corner. Closed: a rounded
    // rectangle. Open: the top edge turns down the panel's left side, round its bottom, and
    // back out to the right edge. The frame is everything outside it.
    readonly property string hole: {
        const L = inL, T = inT, R = inR, B = inB, c = corner
        // start on the top edge, just right of the left panel (or at the top-left corner)
        let d = `M ${leftOpen ? lx + lf : L + c} ${T} `
        // along the top edge, then down round the stats panel, or round the top-right corner
        if (panelOpen)
            d += `L ${px - f} ${T} A ${f} ${f} 0 0 1 ${px} ${T + f} `
               + `L ${px} ${T + panelH - r} A ${r} ${r} 0 0 0 ${px + r} ${T + panelH} `
               + `L ${R - f} ${T + panelH} A ${f} ${f} 0 0 1 ${R} ${T + panelH + f} `
        else
            d += `L ${R - c} ${T} A ${c} ${c} 0 0 1 ${R} ${T + c} `
        // down the right edge, along the bottom, up the left edge
        d += `L ${R} ${B - c} A ${c} ${c} 0 0 1 ${R - c} ${B} `
        if (bottomOpen)
            d += `L ${brt + bf} ${B} A ${bf} ${bf} 0 0 1 ${brt} ${B - bf} `
               + `L ${brt} ${B - bottomH + br} A ${br} ${br} 0 0 0 ${brt - br} ${B - bottomH} `
               + `L ${bl + br} ${B - bottomH} A ${br} ${br} 0 0 0 ${bl} ${B - bottomH + br} `
               + `L ${bl} ${B - bf} A ${bf} ${bf} 0 0 1 ${bl - bf} ${B} `
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

    // ---- inlet shadow: dark for a while, then fading out (like a window's shadow) ----
    // The frame's shape, grown inward by a black stroke along its inner edge (the dark stretch),
    // then blurred (the fade). `shadowGrow` is how far in it stays dark; `shadowFade` is the blur.
    readonly property real shadowGrow: 10
    readonly property real shadowFade: 24
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: frame.shadowFade
            blur: 1.0
        }
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: "#a6000000"
            PathSvg {
                path: `M -20 -20 L ${frame.width + 20} -20 L ${frame.width + 20} ${frame.height + 20} `
                    + `L -20 ${frame.height + 20} Z ` + frame.hole
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: "#a6000000"
            strokeWidth: frame.shadowGrow * 2
            PathSvg { path: frame.hole }
        }
    }

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
