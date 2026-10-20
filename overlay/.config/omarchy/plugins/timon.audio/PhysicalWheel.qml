import QtQuick

// Bar icon wheel in the direction the fingers/wheel physically move.
// With touchpad natural scrolling the compositor flips the scroll values and
// marks the event `inverted`; the stock button only passes angleDelta.y on,
// so swiping up lowered the volume. This undoes that flip (a mouse wheel
// without natural scrolling is unchanged) and calls the button's
// wheelMoved(delta) as before. Place it last inside the BarIconButton.
Item {
  anchors.fill: parent
  z: 100

  WheelHandler {
    onWheel: function(event) {
      var dy = event.angleDelta.y
      if (event.inverted) dy = -dy
      if (dy !== 0) parent.parent.wheelMoved(dy)
    }
  }
}
