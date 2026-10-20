.pragma library
// Shared between the overlay (Clipboard.qml) and the bar icon (BarWidget.qml):
// a .pragma library script is one instance per engine, so the bar icon can
// hand its button to the overlay, which anchors the popup under it.
var overlay = null
var button = null
var bar = null
var widget = null

function setOverlay(o) {
  overlay = o
  if (overlay && button) overlay.setAnchor(button, bar, widget)
}

function clearOverlay(o) {
  if (overlay === o) overlay = null
}

function setAnchor(b, br, w) {
  button = b
  bar = br
  widget = w || null
  if (overlay) overlay.setAnchor(b, br, widget)
}

function clearAnchor(b) {
  if (button !== b) return
  button = null
  bar = null
  widget = null
  if (overlay) overlay.setAnchor(null, null, null)
}

// Bar icon click: toggle the overlay directly (no IPC round trip).
function toggle() {
  if (!overlay) return false
  overlay.toggle()
  return true
}
