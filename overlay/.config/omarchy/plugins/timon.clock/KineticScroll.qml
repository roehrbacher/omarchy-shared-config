// Touchpad momentum for a Flickable (same behaviour as timon.clipboard):
// two-finger scrolling moves the list 1:1 and keeps gliding after lift-off.
import QtQuick

WheelHandler {
  id: handler
  required property Flickable flickable
  property real wheelStep: 60
  property real velocity: 0
  property real lastTime: 0

  target: null
  acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

  function scrollBy(dy) {
    var f = handler.flickable
    var maxY = f.originY + Math.max(0, f.contentHeight - f.height)
    f.contentY = Math.max(f.originY, Math.min(maxY, f.contentY + dy))
  }

  onWheel: function(event) {
    var now = Date.now()
    var f = handler.flickable
    if (event.phase === Qt.ScrollEnd) {
      var v = (now - handler.lastTime) > 80 || Math.abs(handler.velocity) < 150 ? 0 : handler.velocity
      handler.velocity = 0
      if (v !== 0) f.flick(0, v)
      return
    }
    if (event.phase === Qt.ScrollBegin) { handler.velocity = 0; handler.lastTime = now }
    if (event.pixelDelta.y !== 0) {
      f.cancelFlick()
      var dt = Math.max(1, now - handler.lastTime)
      var instant = event.pixelDelta.y * 1000 / dt
      handler.velocity = dt > 100 ? instant : handler.velocity * 0.6 + instant * 0.4
      handler.lastTime = now
      handler.scrollBy(-event.pixelDelta.y)
      return
    }
    if (event.angleDelta.y !== 0) {
      f.cancelFlick()
      handler.scrollBy(-event.angleDelta.y / 120 * handler.wheelStep)
    }
  }
}
