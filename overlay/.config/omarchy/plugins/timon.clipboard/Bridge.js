.pragma library
// Shared between the overlay (Clipboard.qml) and the bar icon (BarWidget.qml):
// a .pragma library script is one instance per engine, so the bar icon can
// hand its button to the overlay, which anchors the popup under it.
var overlay = null
var button = null
var bar = null

function setOverlay(o) {
  overlay = o
  if (overlay && button) overlay.setAnchor(button, bar)
}

function clearOverlay(o) {
  if (overlay === o) overlay = null
}

function setAnchor(b, br) {
  button = b
  bar = br
  if (overlay) overlay.setAnchor(b, br)
}

function clearAnchor(b) {
  if (button !== b) return
  button = null
  bar = null
  if (overlay) overlay.setAnchor(null, null)
}

// Bar icon click: toggle the overlay directly (no IPC round trip).
function toggle() {
  if (!overlay) return false
  overlay.toggle()
  return true
}
