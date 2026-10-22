// History model for timon.clipboard. Pure functions, no QML, so the same file
// runs under node for tests (tests/history.test.js).
//
// Based on Omarchy's stock clipboard plugin (shell/plugins/clipboard), plus
// pinned entries, regex search and a limit that only counts unpinned entries,
// modelled on GNOME Clipboard History.

function normalizeEntry(value) {
  if (typeof value === "string")
    return value.trim().length > 0 ? { type: "text", text: value } : null

  if (!value || typeof value !== "object") return null

  var type = String(value.type || value.kind || "")
  var entry = null
  if (type === "text") {
    var text = String(value.text || "")
    if (text.trim().length === 0) return null
    entry = { type: "text", text: text }
  } else if (type === "image") {
    var path = String(value.path || "")
    if (!path) return null
    entry = { type: "image", path: path, mime: String(value.mime || "image/png") }
    if (value.capturedAt !== undefined && value.capturedAt !== null)
      entry.capturedAt = String(value.capturedAt)
  } else {
    return null
  }
  if (value.pinned === true) entry.pinned = true
  if (entry.type === "text" && value.origin === "phone") entry.origin = "phone"
  return entry
}

function entryKey(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image:" + String(entry.path || "")
  return "text:" + String(entry.text || "")
}

function parseHistory(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    var next = []
    if (!Array.isArray(parsed)) return next
    for (var i = 0; i < parsed.length; i++) {
      var entry = normalizeEntry(parsed[i])
      if (entry) next.push(entry)
    }
    return next
  } catch (e) {
    return []
  }
}

function limitOf(limit, fallback) {
  var max = limit === undefined || limit === null ? fallback : Number(limit)
  if (isNaN(max)) max = fallback
  return Math.max(0, max)
}

// Newest first. A copy of something already in the history moves it to the
// top and keeps its pin. `limit` caps the unpinned entries only: pinned ones
// are never dropped by the limit (GNOME "favorites").
function addEntry(history, entry, limit) {
  var max = limitOf(limit, 500)
  var values = Array.isArray(history) ? history : []
  var normalized = normalizeEntry(entry)
  if (!normalized) return pruneToLimit(values, max)

  var key = entryKey(normalized)
  for (var i = 0; i < values.length; i++) {
    var existing = normalizeEntry(values[i])
    // A pinned entry keeps its place, so the dragged pin order stays put.
    if (existing && entryKey(existing) === key && existing.pinned) {
      var kept = values.slice()
      normalized.pinned = true
      kept[i] = normalized
      return pruneToLimit(kept, max)
    }
  }

  var next = [normalized]
  for (var j = 0; j < values.length; j++) {
    var e = normalizeEntry(values[j])
    if (!e || entryKey(e) === key) continue
    next.push(e)
  }
  return pruneToLimit(next, max)
}

function pruneToLimit(history, limit) {
  var max = limitOf(limit, 500)
  var out = []
  var unpinned = 0
  for (var i = 0; i < history.length; i++) {
    var e = history[i]
    if (!e) continue
    if (!e.pinned) {
      if (unpinned >= max) continue
      unpinned++
    }
    out.push(e)
  }
  return out
}

function removeEntryAt(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var next = values.slice()
  next.splice(target, 1)
  return next
}

function togglePinAt(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()
  var next = values.slice()
  var entry = normalizeEntry(next[target])
  if (!entry) return next
  if (entry.pinned) delete entry.pinned
  else entry.pinned = true
  next[target] = entry
  return next
}

// New pinned order from a drag. `order` lists history indexes of pinned
// entries in their new display order; those entries are put back into the
// same history positions they used (in that order), so nothing else moves.
function reorderPinned(history, order) {
  var values = Array.isArray(history) ? history : []
  var ids = Array.isArray(order) ? order.map(Number) : []
  var slots = ids.slice().sort(function(a, b) { return a - b })
  for (var k = 0; k < slots.length; k++) {
    var e = values[slots[k]]
    if (!e || e.pinned !== true || (k > 0 && slots[k] === slots[k - 1])) return values.slice()
  }
  var next = values.slice()
  for (var i = 0; i < slots.length; i++) next[slots[i]] = values[ids[i]]
  return next
}

// "Clear history" keeps pinned entries, like GNOME.
function clearHistory(history) {
  var values = Array.isArray(history) ? history : []
  var out = []
  for (var i = 0; i < values.length; i++) {
    var e = normalizeEntry(values[i])
    if (e && e.pinned) out.push(e)
  }
  return out
}

function parseEntryJson(line) {
  var raw = String(line || "").trim()
  if (!raw) return null
  try { return normalizeEntry(JSON.parse(raw)) } catch (e) { return null }
}

function searchableText(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image screenshot " + String(entry.mime || "") + " " + String(entry.capturedAt || "")
  return String(entry.text || "") + " " + fileEntryText(entry)
}

// Case-insensitive regex like GNOME; anything that is not a valid regex is
// matched as plain text, so "c++" or "(" still work.
function makeMatcher(query) {
  var needle = String(query || "").trim()
  if (!needle) return function() { return true }
  var lower = needle.toLowerCase()
  var re = null
  try { re = new RegExp(needle, "i") } catch (e) { re = null }
  return function(text) {
    var s = String(text || "")
    if (s.toLowerCase().indexOf(lower) >= 0) return true
    return re !== null && re.test(s)
  }
}

function decodeFileUri(uri) {
  var value = String(uri || "").trim()
  if (value.indexOf("file://") !== 0) return ""
  var path = value.substring(7)
  if (path.indexOf("localhost/") === 0) path = path.substring(9)
  if (path.charAt(0) !== "/") return ""
  try { return decodeURIComponent(path) } catch (e) { return path }
}

function filePaths(entry) {
  if (!entry || entry.type !== "text") return []
  var lines = String(entry.text || "").split(/\r?\n/)
  var paths = []
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() === "") continue
    var path = decodeFileUri(lines[i])
    if (!path) return []
    paths.push(path)
  }
  return paths
}

function fileName(path) {
  var parts = String(path || "").split("/")
  return parts.length > 0 ? parts[parts.length - 1] : String(path || "")
}

function isImagePath(path) {
  return /\.(png|jpe?g|webp|gif|bmp|tiff?)$/i.test(String(path || ""))
}

function fileEntryText(entry) {
  var paths = filePaths(entry)
  if (paths.length === 0) return ""
  if (paths.length === 1) return fileName(paths[0])
  return paths.length + " files"
}

function imagePreviewText(entry) {
  var timestamp = String(entry && entry.capturedAt || "")
  if (!timestamp) return "Image"
  var label = String(entry && entry.mime || "") === "image/png" ? "Screenshot" : "Image"
  return label + " from " + timestamp
}

function previewText(entry) {
  if (!entry) return ""
  if (entry.type === "image") return imagePreviewText(entry)
  var fileText = fileEntryText(entry)
  if (fileText) return fileText
  return String(entry.text || "").replace(/\s+/g, " ").trim()
}

function fullText(entry) {
  if (!entry) return ""
  var paths = filePaths(entry)
  if (paths.length > 0) return paths.join("\n")
  return String(entry.text || "")
}

// Only a prefix of each entry is searched and rendered, so one huge paste
// cannot stall the shell. Pasting reads the full entry from disk by index.
var displayTextLimit = 8192

function cappedEntry(entry) {
  if (!entry || entry.type !== "text" || entry.text.length <= displayTextLimit) return entry
  var cut = entry.text.lastIndexOf("\n", displayTextLimit)
  var capped = { type: "text", text: entry.text.slice(0, cut > 0 ? cut : displayTextLimit) }
  if (entry.pinned) capped.pinned = true
  if (entry.origin) capped.origin = entry.origin
  return capped
}

// Rows for the popup: pinned entries first, then history, both newest first.
// `slot` is the 1-based position in display order, pinned first (Alt+N).
function displayRows(history, query, limit) {
  var values = Array.isArray(history) ? history : []
  var max = limitOf(limit, 200)
  if (max === 0) return []
  var match = makeMatcher(query)
  var pinnedRows = []
  var rows = []

  for (var i = 0; i < values.length; i++) {
    var entry = cappedEntry(normalizeEntry(values[i]))
    if (!entry) continue
    if (!match(searchableText(entry))) continue
    var paths = filePaths(entry)
    var isFile = paths.length > 0
    var isImage = entry.type === "image"
    var previewPath = isImage ? String(entry.path || "") : (isFile && paths.length === 1 && isImagePath(paths[0]) ? paths[0] : "")
    var row = {
      entryType: isFile ? "file" : entry.type,
      fullText: isImage ? "" : fullText(entry),
      previewText: previewText(entry),
      previewImage: previewPath,
      path: isImage ? String(entry.path || "") : (isFile && paths.length === 1 ? paths[0] : ""),
      mime: isImage ? String(entry.mime || "image/png") : "text/plain",
      pinned: entry.pinned === true,
      fromPhone: entry.origin === "phone",
      index: i
    }
    if (row.pinned) pinnedRows.push(row)
    else rows.push(row)
  }

  var out = []
  for (var p = 0; p < pinnedRows.length && out.length < max; p++) {
    pinnedRows[p].slot = out.length + 1
    out.push(pinnedRows[p])
  }
  for (var r = 0; r < rows.length && out.length < max; r++) {
    rows[r].slot = out.length + 1
    out.push(rows[r])
  }
  return out
}

// ---- search field keys ----------------------------------------------------
// Which popup action a key press in the search field triggers. "" means the
// key belongs to the text field itself, so normal editing works: typing,
// Backspace, Ctrl+Backspace, Ctrl+A, Ctrl+V, Ctrl+Z, Left/Right and
// Shift+arrows / Shift+Home / Shift+End selection.
// Key codes are Qt's (Qt.Key_*), so node tests need no QML.
var KEY = {
  Escape: 0x01000000, Return: 0x01000004, Enter: 0x01000005, Insert: 0x01000006, Delete: 0x01000007,
  Home: 0x01000010, End: 0x01000011, Left: 0x01000012, Up: 0x01000013,
  Right: 0x01000014, Down: 0x01000015, PageUp: 0x01000016, PageDown: 0x01000017,
  A: 0x41, C: 0x43, F: 0x46, I: 0x49, J: 0x4a, K: 0x4b, P: 0x50, S: 0x53, U: 0x55, V: 0x56, X: 0x58,
  Shift: 0x01000020, Control: 0x01000021, Meta: 0x01000022, Alt: 0x01000023, AltGr: 0x01001103
}

// Esc in the popup: clear a search (which also collapses the field), else
// collapse an open empty field, else close the popup.
function escapeAction(filterText, expanded) {
  if (String(filterText || "") !== "") return "clear"
  return expanded ? "collapse" : "close"
}

// Header shows the search field while expanded or while there is a search.
function searchShown(filterText, expanded) {
  return expanded === true || String(filterText || "") !== ""
}

// ev: { key, ctrl, alt, shift, hasSelection }
function searchKeyAction(ev) {
  var key = ev.key
  var digit = key >= 0x31 && key <= 0x39
  if (key === KEY.Escape) return "escape"
  if (digit && ev.alt && !ev.ctrl) return "slot"
  if (ev.ctrl && !ev.alt && (key === KEY.C || key === KEY.Insert)) return ev.hasSelection ? "copySelection" : ""
  if (ev.ctrl && !ev.alt && key === KEY.X) return ev.hasSelection ? "cutSelection" : ""
  // Qt's own Ctrl+U would also copy the line to the clipboard; just clear.
  if (ev.ctrl && !ev.alt && key === KEY.U) return "clearSearch"
  // Ctrl+P pins (Ctrl+F still works); Ctrl+I toggles incognito.
  if (ev.ctrl && (key === KEY.P || key === KEY.F)) return "pin"
  if (ev.ctrl && key === KEY.I) return "private"
  if (ev.ctrl && !ev.alt && key === KEY.S) return "send"
  if (key === KEY.Delete) {
    if (ev.shift) return "clear"
    return ev.hasSelection ? "" : "delete"
  }
  if (!ev.shift && (key === KEY.Up || (ev.ctrl && key === KEY.K))) return "up"
  if (!ev.shift && (key === KEY.Down || (ev.ctrl && key === KEY.J))) return "down"
  if (key === KEY.PageUp) return "pageUp"
  if (key === KEY.PageDown) return "pageDown"
  if (!ev.shift && key === KEY.Home) return "home"
  if (!ev.shift && key === KEY.End) return "end"
  if (key === KEY.Return || key === KEY.Enter) return "enter"
  return ""
}

// ---- v1.3 helpers -----------------------------------------------------------

// Alt+N: display index of the Nth row (top to bottom), or -1.
function slotRowIndex(rows, slot) {
  var list = rows || []
  for (var i = 0; i < list.length; i++) if (list[i].slot === slot) return i
  return -1
}

// Row actions (send, pin, trash) on the selected row, by keyboard.
// focus: -1 = the row itself, else index into the visible actions.
// ev: { key, ctrl, alt, shift, atTextEnd }. Returns { focus, consumed, trigger }.
// Right enters the actions only when the search cursor is at the end, so
// Left/Right keep moving the text cursor while you edit the search.
// Row actions left to right: phone (send), trash, pin. Pin is last so it
// stays in the slot where a pinned row shows it when not hovered.
function rowActionNames(armed, phoneOnline, isText) {
  if (armed) return ["delete"]
  var out = []
  if (phoneOnline && isText) out.push("send")
  out.push("delete")
  out.push("pin")
  return out
}

function actionFocusStep(focus, count, ev) {
  var f = count > 0 ? Math.min(focus, count - 1) : -1
  var plain = !ev.ctrl && !ev.alt && !ev.shift
  var out = { focus: f, consumed: false, trigger: false }
  if (count <= 0) { out.focus = -1; return out }
  if (plain && ev.key === KEY.Right) {
    if (f >= 0) { out.focus = Math.min(count - 1, f + 1); out.consumed = true }
    else if (ev.atTextEnd) { out.focus = 0; out.consumed = true }
  } else if (plain && ev.key === KEY.Left) {
    if (f >= 0) { out.focus = f - 1; out.consumed = true }
  } else if (f >= 0 && plain && (ev.key === KEY.Return || ev.key === KEY.Enter)) {
    out.consumed = true; out.trigger = true
  } else if (f >= 0 && ev.key === KEY.Escape) {
    out.focus = -1; out.consumed = true
  } else if (f >= 0 && (ev.key === KEY.Up || ev.key === KEY.Down)) {
    out.focus = -1
  }
  return out
}

// Alt+N paste fires when the held modifier is released, so the
// synthetic Shift+Insert is not combined with a still-held Ctrl or Alt
// (Ctrl+Shift+Insert / Alt+Shift+Insert is not "paste" in most apps).
function isModifierKey(key) {
  return key === KEY.Shift || key === KEY.Control || key === KEY.Meta || key === KEY.Alt || key === KEY.AltGr
}

// Del: unpinned rows go at once; a pinned row needs a second Del while armed.
function deleteAction(pinned, armed) {
  return pinned === true && armed !== true ? "arm" : "delete"
}

// "119 items · 3 pinned", "1 item", "4 of 119 items · 3 pinned" while searching.
function countLabel(total, pinned, shown, filtering) {
  var n = Math.max(0, Number(total) || 0)
  var items = n === 1 ? "1 item" : n + " items"
  // Pinned items are not counted separately (their section shows them).
  return filtering ? (Number(shown) || 0) + " of " + items : items
}

function pinnedCount(history) {
  var values = Array.isArray(history) ? history : []
  var n = 0
  for (var i = 0; i < values.length; i++) if (values[i] && values[i].pinned === true) n++
  return n
}

// Popup size factor from the screen's logical height: 1.0 from 1080 px up
// (24" 1080p monitor), down to 0.85 on small laptop screens.
function popupScale(logicalHeight) {
  var h = Number(logicalHeight) || 1080
  return Math.max(0.85, Math.min(1, h / 1080))
}

// Flux (`flux-cli status --json`): did this text just arrive from a device?
// fluxd records an incoming copy (dir "in") before it puts it on the
// clipboard, so a matching recent "in" entry means it came from the phone.
function fluxOrigin(status, text, nowSec, windowSec) {
  if (!status || !Array.isArray(status.clipboard) || !text) return ""
  var win = windowSec === undefined ? 20 : windowSec
  for (var i = 0; i < status.clipboard.length; i++) {
    var c = status.clipboard[i]
    if (c && c.dir === "in" && c.text === text && Math.abs(Number(nowSec) - Number(c.time)) <= win) return "phone"
  }
  return ""
}

// Is a paired phone online in Flux right now?
function fluxPhoneOnline(status) {
  if (!status || !Array.isArray(status.devices)) return false
  for (var i = 0; i < status.devices.length; i++) {
    var d = status.devices[i]
    if (d && d.paired === true && d.online === true) return true
  }
  return false
}

// Name of the first online paired phone, "" when none.
function fluxPhoneName(status) {
  if (!status || !Array.isArray(status.devices)) return ""
  for (var i = 0; i < status.devices.length; i++) {
    var d = status.devices[i]
    if (d && d.paired === true && d.online === true) return String(d.name || "Phone")
  }
  return ""
}

// Newest clipboard sync time (unix seconds) in a Flux status, 0 when none.
function fluxLastSync(status) {
  if (!status || !Array.isArray(status.clipboard)) return 0
  var t = 0
  for (var i = 0; i < status.clipboard.length; i++) {
    var c = status.clipboard[i]
    if (c && Number(c.time) > t) t = Number(c.time)
  }
  return t
}

// "just now", "5 min ago", "2 h ago", "3 d ago", or "never".
function agoLabel(timeSec, nowSec) {
  if (!timeSec) return "never"
  var d = Math.max(0, Math.floor(Number(nowSec) - Number(timeSec)))
  if (d < 60) return "just now"
  if (d < 3600) return Math.floor(d / 60) + " min ago"
  if (d < 86400) return Math.floor(d / 3600) + " h ago"
  return Math.floor(d / 86400) + " d ago"
}

// Footer phone button state from flux-pause.sh's answer ("absent",
// "running", "paused", "off") and whether a phone is online: "" (hidden,
// Flux not installed), "online", "nophone", "paused" (incognito) or "off".
function phoneIconState(fluxState, phoneOnline) {
  if (!fluxState || fluxState === "absent") return ""
  if (fluxState === "paused") return "paused"
  if (fluxState === "off") return "off"
  return phoneOnline ? "online" : "nophone"
}

// Tooltip for the footer phone button.
// Footer clear button text. long = "󰩺  Clear history (162 items)",
// short = "󰩺  Clear history (162)".
function clearLabelText(count, long) {
  var n = Math.max(0, count | 0)
  return "󰩺  Clear history (" + n + (long ? (n === 1 ? " item)" : " items)") : ")")
}

// Pick the long label only if its width plus a comfortable gap fits in the
// free footer space; otherwise the short one.
function clearLabel(count, longWidth, available, minGap) {
  return clearLabelText(count, longWidth + minGap <= available)
}

function phoneTooltip(state, phoneName) {
  if (state === "online") return (phoneName || "Phone") + " connected via Flux"
  if (state === "paused") return "Flux paused (incognito)"
  if (state === "off") return "Flux not running"
  if (state === "nophone") return "No phone connected"
  return ""
}

// Mark the text entry `text` with an origin ("phone"); returns a new array.
function setOrigin(history, text, origin) {
  var values = Array.isArray(history) ? history.slice() : []
  for (var i = 0; i < values.length; i++) {
    var e = values[i]
    if (e && e.type === "text" && e.text === text) {
      var copy = normalizeEntry(e)
      if (origin) copy.origin = origin
      values[i] = copy
      break
    }
  }
  return values
}

// ---- touchpad momentum ------------------------------------------------------
// Velocity (px/s) of a touchpad scroll, from its pixel deltas. A pause longer
// than 100 ms starts over; otherwise the speed is smoothed so the last few
// events count most. When the fingers lift (ScrollEnd) the list is flicked
// with this speed and slows down by itself (Flickable deceleration).
function kineticVelocity(prevVelocity, dy, dtMs) {
  var dt = Math.max(1, Number(dtMs) || 1)
  var instant = Number(dy) * 1000 / dt
  if (dt > 100) return instant
  return prevVelocity * 0.6 + instant * 0.4
}

// Flick after lift-off only if the fingers were still moving at the end.
function kineticFlickVelocity(velocity, msSinceLastDelta) {
  if (msSinceLastDelta > 80) return 0
  return Math.abs(velocity) < 150 ? 0 : velocity
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeEntry: normalizeEntry,
    entryKey: entryKey,
    parseHistory: parseHistory,
    addEntry: addEntry,
    pruneToLimit: pruneToLimit,
    removeEntryAt: removeEntryAt,
    togglePinAt: togglePinAt,
    reorderPinned: reorderPinned,
    escapeAction: escapeAction,
    searchShown: searchShown,
    clearHistory: clearHistory,
    parseEntryJson: parseEntryJson,
    makeMatcher: makeMatcher,
    searchableText: searchableText,
    previewText: previewText,
    filePaths: filePaths,
    fullText: fullText,
    displayRows: displayRows,
    KEY: KEY,
    searchKeyAction: searchKeyAction,
    slotRowIndex: slotRowIndex,
    isModifierKey: isModifierKey,
    deleteAction: deleteAction,
    countLabel: countLabel,
    pinnedCount: pinnedCount,
    popupScale: popupScale,
    fluxOrigin: fluxOrigin,
    fluxPhoneOnline: fluxPhoneOnline,
    fluxPhoneName: fluxPhoneName,
    fluxLastSync: fluxLastSync,
    agoLabel: agoLabel,
    phoneIconState: phoneIconState,
    phoneTooltip: phoneTooltip,
    clearLabelText: clearLabelText,
    clearLabel: clearLabel,
    setOrigin: setOrigin,
    kineticVelocity: kineticVelocity,
    kineticFlickVelocity: kineticFlickVelocity,
    actionFocusStep: actionFocusStep,
    rowActionNames: rowActionNames
  }
}
