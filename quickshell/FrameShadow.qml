import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The frame's inner shadow: dark for a while past its inner edge, then fading out (like a window's
// shadow). It lives on its own surface below the frame's (see shell.qml) so the blur Hyprland puts
// behind the frame doesn't also smear the windows under the shadow, and it is cut away wherever the
// frame is, so a see-through frame shows no shadow under itself.
Item {
    id: root
    required property var frame         // Frame.qml: its outline (`hole`) and size
    // the frame's shape grown inward by a black stroke (`grow`: how far it stays dark), then blurred
    // (`fade`)
    readonly property real grow: 10
    readonly property real fade: 24
    readonly property string outside: `M -20 -20 L ${width + 20} -20 L ${width + 20} ${height + 20} `
                                      + `L -20 ${height + 20} Z ` + frame.hole

    Item {   // the free area inside the frame: the shadow is only kept there (never shown itself)
        id: freeArea
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: "white"
                PathSvg { path: root.frame.hole }
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
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // rendered and blurred at half resolution (a quarter of the pixels; a soft shadow looks
            // the same): the display runs on the integrated GPU and this is redrawn on every frame of
            // every panel animation. The blur works in texture pixels, so its radius is halved too.
            layer.enabled: true
            layer.textureSize: Qt.size(width / 2, height / 2)
            layer.smooth: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: root.fade / 2
                blur: 1.0
            }
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
                PathSvg { path: root.frame.hole }
            }
        }
    }
}
