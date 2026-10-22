import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The frame's inner shadow: dark for a while past its inner edge, then fading out (like a window's
// shadow). It lives on its own surfaces below the frame's (see shell.qml) so the blur Hyprland puts
// behind the frame doesn't also smear the windows under the shadow, and it is cut away wherever the
// frame is, so a see-through frame shows no shadow under itself.
//
// Used for the frame outside the panels' regions and for each region (Frame.qml): each keeps its
// shadow only inside its own rectangles (`keepRects`), and the outlines they are computed from agree
// away from the panels, so they meet without a seam.
Item {
    id: root
    required property string hole       // the frame's inner outline, in screen coordinates
    property real originX: 0            // where this item sits on the screen
    property real originY: 0
    property real screenW: width
    property real screenH: height
    property var keepRects: null        // [[x, y, w, h], ...] on the screen: shadow only there (null: everywhere)
    // the frame's shape grown inward by a black stroke (`grow`: how far it stays dark), then blurred
    // (`fade`)
    readonly property real grow: 10
    readonly property real fade: 24
    readonly property string outside: `M -20 -20 L ${screenW + 20} -20 L ${screenW + 20} ${screenH + 20} `
                                      + `L -20 ${screenH + 20} Z ` + hole

    Item {   // where the shadow is kept: the free area inside the frame, in keepRects (never shown itself)
        id: freeArea
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Repeater {
            model: root.keepRects || [[root.originX, root.originY, root.width, root.height]]
            delegate: Item {
                id: keep
                required property var modelData
                x: modelData[0] - root.originX
                y: modelData[1] - root.originY
                width: modelData[2]
                height: modelData[3]
                clip: true
                Shape {
                    x: -root.originX - keep.x
                    y: -root.originY - keep.y
                    width: root.screenW; height: root.screenH
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        strokeWidth: 0
                        fillColor: "white"
                        PathSvg { path: root.hole }
                    }
                }
            }
        }
    }

    // blurred first, then cut (cutting first would let the blur spread back under the frame)
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: freeArea
            // keep the shadow wherever the free area covers any of a pixel: the frame's anti-aliased
            // edge pixels (on the curves) are part see-through, and cutting the shadow there left a
            // thin light line between frame and shadow
            maskThresholdMin: 0.01
        }
        Item {
            anchors.fill: parent
            // rendered and blurred at half resolution (a quarter of the pixels; a soft shadow looks
            // the same). The blur works in texture pixels, so its radius is halved too.
            layer.enabled: true
            layer.textureSize: Qt.size(width / 2, height / 2)
            layer.smooth: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: root.fade / 2
                blur: 1.0
            }
            Shape {
                x: -root.originX; y: -root.originY
                width: root.screenW; height: root.screenH
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillRule: ShapePath.OddEvenFill
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillColor: "#a6000000"
                    PathSvg { path: root.outside }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "#a6000000"
                    strokeWidth: root.grow * 2
                    PathSvg { path: root.hole }
                }
            }
        }
    }
}
