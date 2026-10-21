import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The frame around the monitor, drawn as one gradient-filled shape with no outline: the top band
// (holding the bar) is 56px, the left, right and bottom bands 3px, and the inside edge has rounded
// corners. When the stats panel is open it hangs from the top band at the right, filled like the
// band, with concave joins where it meets the band and the right edge.
Item {
    id: frame
    required property var theme
    readonly property int side: 10        // left/right/bottom band
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
    // back out to the right edge. The frame is everything outside it.
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
