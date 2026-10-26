#version 440
// The frame's fill, or its inner shadow, in one pass from the signed distance to the free area inside
// it (FrameShader.qml): a rounded rectangle (the frame's inside edge) with the open panels' notches,
// joined to the bands by round fillets. Animating a panel only changes the uniforms.
// Compiled with: /usr/lib/qt6/bin/qsb --qt6 -o frame.frag.qsb frame.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 area;          // this item on the screen: x, y, w, h
    vec4 inner;         // the frame's inside edge: left, top, right, bottom
    float corner;       // its corners' radius
    float screenW;
    float shadow;       // 1: the inner shadow, 0: the fill
    float glass;        // 1: a thin light line along the inside edge
    vec4 edgeColor;     // the fill's gradient across the screen: at both sides,
    vec4 midColor;      // and in the middle (Qt passes colors premultiplied)
    vec4 p0; vec4 p1; vec4 p2;   // up to three panels: left, top, right, bottom (reaching into their band)
    vec4 k0; vec4 k1; vec4 k2;   // and their corner radius, join radius, 1 if open
};

float roundBox(vec2 p, vec4 r, float radius) {   // < 0 inside the rectangle r (x0, y0, x1, y1)
    vec2 c = (r.xy + r.zw) * 0.5, h = (r.zw - r.xy) * 0.5;
    vec2 q = abs(p - c) - h + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float roundMax(float a, float b, float k) {   // intersection, its corners rounded by k (the joins)
    vec2 u = max(vec2(k + a, k + b), 0.0);
    return min(-k, max(a, b)) + length(u);
}

float freeDistance(vec2 p) {   // < 0 in the free area, > 0 in the frame
    float d = roundBox(p, inner, corner);
    if (k0.z > 0.5) d = roundMax(d, -roundBox(p, p0, k0.x), k0.y);
    if (k1.z > 0.5) d = roundMax(d, -roundBox(p, p1, k1.x), k1.y);
    if (k2.z > 0.5) d = roundMax(d, -roundBox(p, p2, k2.x), k2.y);
    return d;
}

void main() {
    vec2 p = area.xy + qt_TexCoord0 * area.zw;
    float d = freeDistance(p);
    if (shadow > 0.5) {
        // fitted to the blurred shadow it replaces: darkest at the inside edge, dark for about 7px past
        // it, fading by 15px, with a faint tail; kept over the edge's anti-aliased pixels too (no light
        // line there)
        float t = max(-d, 0.0);
        float s = smoothstep(6.5, 15.0, t);
        float a = max(0.71 - 0.018 * t, 0.0) * (1.0 - s) + 0.10 * exp(-t / 8.0) * s + 0.06 * exp(-t);
        fragColor = vec4(0.0, 0.0, 0.0, d < 0.5 ? a : 0.0) * qt_Opacity;
    } else {
        float cover = clamp(d + 0.5, 0.0, 1.0);
        vec4 c = mix(edgeColor, midColor, 1.0 - abs(2.0 * p.x / screenW - 1.0));
        vec4 col = c * cover;
        if (glass > 0.5) {
            float line = 0.22 * clamp(1.0 - abs(d), 0.0, 1.0);   // 1px, centred on the edge
            col = vec4(line) + col * (1.0 - line);
        }
        fragColor = col * qt_Opacity;
    }
}
