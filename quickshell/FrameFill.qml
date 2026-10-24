import QtQuick
import QtQuick.Shapes

// The frame's fill (its gradient across the screen) outside `hole`, only inside `rect`
// ([x, y, w, h] on the screen). Its parent must span the screen, at the screen's origin.
Item {
    id: root
    required property var theme
    required property var rect
    required property string hole
    property real screenW: parent ? parent.width : 0
    property real screenH: parent ? parent.height : 0

    x: rect[0]; y: rect[1]
    width: rect[2]; height: rect[3]
    clip: true

    Shape {
        x: -root.rect[0]; y: -root.rect[1]
        width: root.screenW; height: root.screenH
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            // glass: a thin light edge along the frame's inside (and round its panels)
            strokeColor: root.theme.glass ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
            strokeWidth: root.theme.glass ? 1 : 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: root.screenW; y2: 0
                GradientStop { position: 0.0; color: root.theme.barEnd }
                GradientStop { position: 0.5; color: root.theme.barStart }
                GradientStop { position: 1.0; color: root.theme.barEnd }
            }
            PathSvg {
                path: `M -20 -20 L ${root.screenW + 20} -20 L ${root.screenW + 20} ${root.screenH + 20} `
                    + `L -20 ${root.screenH + 20} Z ` + root.hole
            }
        }
    }
}
