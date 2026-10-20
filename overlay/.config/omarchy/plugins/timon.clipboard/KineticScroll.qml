// Touchpad momentum for a Flickable/ListView: two-finger scrolling moves the
// list 1:1, and when the fingers lift while moving the list keeps going and
// slows down (Flickable.flick + flickDeceleration), like GTK and browsers.
// Mouse wheel notches (no pixel delta) scroll by `wheelStep` per notch.
import QtQuick
import "ClipboardHistory.js" as ClipboardHistory

WheelHandler {
  id: handler
  required property Flickable flickable
  property real wheelStep: 120
  property real velocity: 0
  property real lastTime: 0

  target: null
  acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

  function scrollBy(dy) {
    var f = handler.flickable
    var maxY = f.originY + Math.max(0, f.contentHeight - f.height)
    f.contentY = Math.max(f.originY, Math.min(maxY, f.contentY + dy))
  }

  // dy: pixel delta (positive = fingers moved down = list moves down).
  function touchpadDelta(dy, nowMs) {
    handler.flickable.cancelFlick()
    handler.velocity = ClipboardHistory.kineticVelocity(handler.velocity, dy, nowMs - handler.lastTime)
    handler.lastTime = nowMs
    handler.scrollBy(-dy)
  }

  function touchpadEnd(nowMs) {
    var v = ClipboardHistory.kineticFlickVelocity(handler.velocity, nowMs - handler.lastTime)
    handler.velocity = 0
    if (v !== 0) handler.flickable.flick(0, v)
  }

  onWheel: function(event) {
    var now = Date.now()
    if (event.phase === Qt.ScrollEnd) { handler.touchpadEnd(now); return }
    if (event.phase === Qt.ScrollBegin) { handler.velocity = 0; handler.lastTime = now }
    if (event.pixelDelta.y !== 0) { handler.touchpadDelta(event.pixelDelta.y, now); return }
    if (event.angleDelta.y !== 0) {
      handler.flickable.cancelFlick()
      handler.scrollBy(-event.angleDelta.y / 120 * handler.wheelStep)
    }
  }
}
