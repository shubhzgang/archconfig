import QtQuick
import Quickshell
import Quickshell.Wayland

// One region of the screen (Frame.qml) on its own surfaces: its piece of the frame with the panels
// that grow there, and below it (unblurred, like the screen's) its piece of the frame's shadow. A
// panel's animation then only redraws its region instead of the whole screen (the display runs on
// the integrated GPU).
//
// The panels go inside as children and are laid out on the screen as before: they sit in an item
// that spans the screen at its origin, which the surface only shows its rectangle of.
Scope {
    id: region
    required property var frame
    required property var theme
    required property string name       // the surfaces' namespaces: qs-region-<name>, qs-shadow-<name>
    required property var rect          // [x, y, w, h] on the screen
    required property string hole       // the outline with this region's panels' notches
    required property var keepRects     // where this region draws the shadow
    property bool active: false         // one of its panels is open: take the keyboard and the mouse
    property bool shown: true           // false while a fullscreen window covers the screen: draw nothing
    signal dismiss()                    // a click outside its panels, or Escape
    default property alias content: screenSpace.data

    // the shadow's surface: 40px larger than the region where the screen allows, so the blur has the
    // frame's outline beyond the region to work from and meets the neighbours' shadow without a seam
    readonly property var shadowRect: {
        const x0 = Math.max(0, rect[0] - 40), y0 = Math.max(0, rect[1] - 40)
        const x1 = Math.min(frame.width, rect[0] + rect[2] + 40), y1 = Math.min(frame.height, rect[1] + rect[3] + 40)
        return [x0, y0, x1 - x0, y1 - y0]
    }

    PanelWindow {
        anchors { top: true; left: true }
        margins { left: region.shadowRect[0]; top: region.shadowRect[1] }
        implicitWidth: region.shadowRect[2]
        implicitHeight: region.shadowRect[3]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-shadow-" + region.name
        contentItem.visible: region.shown && !region.theme.flat   // (none in the one-tone black themes)
        mask: Region {}
        FrameShadow {
            anchors.fill: parent
            hole: region.hole
            originX: region.shadowRect[0]
            originY: region.shadowRect[1]
            screenW: region.frame.width
            screenH: region.frame.height
            keepRects: region.keepRects
        }
    }

    PanelWindow {
        id: surface
        anchors { top: true; left: true }
        margins { left: region.rect[0]; top: region.rect[1] }
        implicitWidth: region.rect[2]
        implicitHeight: region.rect[3]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-region-" + region.name
        contentItem.visible: region.shown
        // The keyboard: taken exclusively for a moment when a panel opens (so typing goes to it at once),
        // then on demand. Hyprland sends every click to a surface that holds the keyboard
        // exclusively, so keeping it would stop the bar and the dock buttons from taking their clicks.
        WlrLayershell.keyboardFocus: !region.active ? WlrKeyboardFocus.None
                                   : grab.running ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        // while a panel is open the whole region takes the mouse (a click beside the panel closes it);
        // otherwise none of it does
        mask: Region { item: region.active ? whole : nothing }

        Timer { id: grab; interval: 200 }
        Connections {
            target: region
            function onActiveChanged() { if (region.active) grab.restart() }
        }

        Item { id: nothing }
        Item { id: whole; anchors.fill: parent }

        Item {
            id: screenSpace
            x: -region.rect[0]; y: -region.rect[1]
            width: region.frame.width; height: region.frame.height

            FrameFill {
                theme: region.theme
                rect: region.rect
                hole: region.hole
            }
            Item {   // a click outside the panels, or Escape when no panel has the keyboard
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: region.dismiss()
                MouseArea { anchors.fill: parent; onClicked: region.dismiss() }
            }
        }
    }
}
