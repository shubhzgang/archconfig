import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The frame around the monitor. The top band (holding the bar) is filled with a gradient across
// the screen; the left, right and bottom sides are only a 3px outline with no fill. When the
// stats panel is open it hangs from the top band at the right, filled like the band, with the
// outline flowing round it (concave joins where it meets the band and the right edge).
Item {
    id: frame
    required property var theme
    readonly property int line: 3         // outline width
    readonly property real side: line / 2 // the left/right/bottom outline sits on the screen edge
    readonly property int band: 56        // top band (the bar)
    readonly property int corner: 28      // radius of the screen's inner corners
    property real panelW: 0               // stats panel hanging from the top band, right-aligned
    property real panelH: 0

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

    // The free area inside the frame, clockwise from the top-left corner. Closed: a rounded
    // rectangle. Open: the top edge turns down the panel's left side, round its bottom, and
    // back out to the right edge. This is the outline.
    readonly property string hole: {
        const L = inL, T = inT, R = inR, B = inB, c = corner
        if (!panelOpen)
            return `M ${L + c} ${T} L ${R - c} ${T} A ${c} ${c} 0 0 1 ${R} ${T + c} L ${R} ${B - c} `
                 + `A ${c} ${c} 0 0 1 ${R - c} ${B} L ${L + c} ${B} A ${c} ${c} 0 0 1 ${L} ${B - c} `
                 + `L ${L} ${T + c} A ${c} ${c} 0 0 1 ${L + c} ${T} Z`
        return `M ${L + c} ${T} L ${px - f} ${T} A ${f} ${f} 0 0 1 ${px} ${T + f} `
             + `L ${px} ${T + panelH - r} A ${r} ${r} 0 0 0 ${px + r} ${T + panelH} `
             + `L ${R - f} ${T + panelH} A ${f} ${f} 0 0 1 ${R} ${T + panelH + f} `
             + `L ${R} ${B - c} A ${c} ${c} 0 0 1 ${R - c} ${B} L ${L + c} ${B} A ${c} ${c} 0 0 1 ${L} ${B - c} `
             + `L ${L} ${T + c} A ${c} ${c} 0 0 1 ${L + c} ${T} Z`
    }

    // The filled area: the top band, the corner pieces where the rounded outline curves away
    // from the screen corners (all four, extended past the screen edge so no gap shows), and
    // (open) the panel with its two concave joins. Clockwise from the top left.
    readonly property string fillArea: {
        const L = inL, T = inT, R = inR, B = inB, c = corner, W = width, H = height
        const head = `M -20 -20 L ${W + 20} -20 L ${W + 20} `
        const tail = ` L ${L + c} ${T} A ${c} ${c} 0 0 0 ${L} ${T + c} L -20 ${T + c} Z `
        const bottom = `M ${L} ${B - c} A ${c} ${c} 0 0 0 ${L + c} ${B} L ${L + c} ${H + 20} L -20 ${H + 20} L -20 ${B - c} Z `
                     + `M ${R - c} ${B} A ${c} ${c} 0 0 0 ${R} ${B - c} L ${W + 20} ${B - c} L ${W + 20} ${H + 20} L ${R - c} ${H + 20} Z`
        if (!panelOpen)
            return head + `${T + c} L ${R} ${T + c} A ${c} ${c} 0 0 0 ${R - c} ${T}` + tail + bottom
        return head + `${T + panelH + f} L ${R} ${T + panelH + f} A ${f} ${f} 0 0 0 ${R - f} ${T + panelH} `
             + `L ${px + r} ${T + panelH} A ${r} ${r} 0 0 1 ${px} ${T + panelH - r} `
             + `L ${px} ${T + f} A ${f} ${f} 0 0 0 ${px - f} ${T}` + tail + bottom
    }

    // ---- fill: gradient across the screen ----
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: frame.width; y2: 0
                GradientStop { position: 0.0; color: frame.theme.barEnd }
                GradientStop { position: 0.5; color: frame.theme.barStart }
                GradientStop { position: 1.0; color: frame.theme.barEnd }
            }
            PathSvg { path: frame.fillArea }
        }
    }

    // ---- outline: the whole frame edge, 3px, no fill ----
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: frame.theme.accent
            strokeWidth: frame.line
            PathSvg { path: frame.hole }
        }
    }
}
