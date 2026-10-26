import QtQuick

// The frame's fill, or its inner shadow (`isShadow`), inside `rect` ([x, y, w, h] on the screen), in one
// pass (shaders/frame.frag): computed per pixel from the distance to the frame's inside edge and the
// open panels' notches (`panels`, from Frame.notches()), so animating a panel only changes numbers:
// no outline to rebuild and triangulate, no offscreen layers to blur and mask.
ShaderEffect {
    id: root
    required property var outline       // Frame.qml: the inside edge, its corners, the screen's width
    required property var theme
    required property var rect
    property var panels: []             // up to three: [x0, y0, x1, y1, corner radius, join radius]
    property bool isShadow: false
    property real originX: 0            // where the parent sits on the screen
    property real originY: 0

    x: rect[0] - originX; y: rect[1] - originY
    width: rect[2]; height: rect[3]

    // the shader's uniforms
    readonly property vector4d area: Qt.vector4d(rect[0], rect[1], rect[2], rect[3])
    readonly property vector4d inner: Qt.vector4d(outline.inL, outline.inT, outline.inR, outline.inB)
    readonly property real corner: outline.corner
    readonly property real screenW: outline.width
    readonly property real shadow: isShadow ? 1 : 0
    readonly property real glass: theme.glass ? 1 : 0
    readonly property color edgeColor: theme.barEnd
    readonly property color midColor: theme.barStart
    function notch(i) { const n = panels[i]; return n ? Qt.vector4d(n[0], n[1], n[2], n[3]) : Qt.vector4d(0, 0, 0, 0) }
    function radii(i) { const n = panels[i]; return n ? Qt.vector4d(n[4], n[5], 1, 0) : Qt.vector4d(0, 0, 0, 0) }
    readonly property vector4d p0: notch(0)
    readonly property vector4d p1: notch(1)
    readonly property vector4d p2: notch(2)
    readonly property vector4d k0: radii(0)
    readonly property vector4d k1: radii(1)
    readonly property vector4d k2: radii(2)

    fragmentShader: Qt.resolvedUrl("shaders/frame.frag.qsb")
}
