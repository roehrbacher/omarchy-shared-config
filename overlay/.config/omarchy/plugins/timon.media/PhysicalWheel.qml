import QtQuick
import Quickshell.Io

// Bar icon wheel in the direction the fingers/wheel physically move:
// fingers (or wheel) down = less, up = more, whatever natural scrolling says.
//
// Why this is needed (upstream bug): with touchpad natural_scroll, libinput
// flips the scroll values, and Wayland's wl_pointer.axis_relative_direction
// should then say INVERTED so clients can undo it (Qt exposes that as
// WheelEvent.inverted). Hyprland 0.56.2 hardcodes IDENTICAL in
// InputManager::onMouseWheel (hyprwm/Hyprland discussion #16479), so Qt's
// `inverted` is always false. We therefore also ask Hyprland whether touchpad
// natural scrolling is on and flip finger-scroll events ourselves. If Hyprland
// ever sends INVERTED, `inverted` is honoured and we don't flip twice.
// Mouse wheels follow input:natural_scroll the same way.
//
// Place it last inside a BarIconButton (calls the button's wheelMoved(delta)),
// or set handle: false and call physicalDy(event) from your own handler.
Item {
  id: pw
  anchors.fill: parent
  z: 100

  property bool handle: true
  property bool naturalTouchpad: false
  property bool naturalMouse: false

  function isFinger(event) {
    return (event.pixelDelta && event.pixelDelta.y !== 0)
      || (event.device && event.device.type === PointerDevice.TouchPad)
  }

  function physicalDy(event) {
    var dy = event.angleDelta.y
    if (event.inverted) return -dy
    if (isFinger(event) ? pw.naturalTouchpad : pw.naturalMouse) return -dy
    return dy
  }

  Process {
    id: optProc
    property string which: "touchpad"
    command: ["hyprctl", "getoption", which === "touchpad" ? "input:touchpad:natural_scroll" : "input:natural_scroll", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var on = /"bool":\s*true|"int":\s*1/.test(text)
        if (optProc.which === "touchpad") { pw.naturalTouchpad = on; optProc.which = "mouse"; optProc.running = true }
        else pw.naturalMouse = on
      }
    }
  }
  Component.onCompleted: optProc.running = true

  WheelHandler {
    enabled: pw.handle
    onWheel: function(event) {
      var dy = pw.physicalDy(event)
      if (dy !== 0) pw.parent.wheelMoved(dy)
    }
  }
}
