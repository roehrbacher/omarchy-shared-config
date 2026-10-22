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

// Heading for a row: "Results · N" for every row while searching (so the
// heading row stays and the list doesn't jump), else Pinned / History
// (History only shown when there are pins).
function sectionName(pinned, pinnedCount, filtering, count) {
  if (filtering) return "Results · " + count
  if (pinned) return "Pinned"
  return pinnedCount > 0 ? "History" : ""
}

// ---- links and e-mail addresses ------------------------------------------
// Real TLDs that are not also common file extensions (so notes.txt,
// script.sh, main.py, README.md, photo.png never count as a domain).
var LINK_TLDS = ("com net org edu gov mil int info biz name pro io ai app dev me co tv cc xyz "
  + "online site tech store shop blog news cloud page live link email world today space "
  + "at de ch li eu uk fr it es nl be lu dk se no fi is pl cz sk hu si hr ro bg gr pt ie "
  + "ee lv lt ua us ca mx br ar cl au nz jp cn kr in sg hk tw za tr il ae ru").split(" ")

function hasLinkTld(host) {
  var parts = String(host).toLowerCase().split(".")
  return parts.length >= 2 && parts[0] !== "" && LINK_TLDS.indexOf(parts[parts.length - 1]) >= 0
}

// One trimmed single-line text that is a link or an e-mail address, else
// null. { kind: "url" | "mail", target } where target is what xdg-open gets
// (https:// added when there is no scheme; mailto: for addresses).
function linkTarget(text) {
  var s = String(text || "").trim()
  if (s === "" || /\s/.test(s) || s.length > 2048) return null
  var m = /^mailto:([^\s@]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+))$/i.exec(s) || /^([^\s@\/:]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+))$/.exec(s)
  if (m) return hasLinkTld(m[2]) ? { kind: "mail", target: "mailto:" + m[1] } : null
  if (/^https?:\/\/[^\/\s?#]+/i.test(s)) return { kind: "url", target: s }
  var d = /^((?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,})(:\d{1,5})?([\/?#]\S*)?$/.exec(s)
  if (!d) return null
  if (!/^www\./i.test(d[1]) && !hasLinkTld(d[1])) return null
  if (/^www\./i.test(d[1]) && d[1].split(".").length < 3) return null
  return { kind: "url", target: "https://" + s }
}

// Phone number: international (+43 / 0043) or national (0664 ...) format,
// digits with spaces, dashes, dots, slashes or brackets; 7-15 digits.
function phoneTarget(text) {
  var s = String(text || "").trim()
  if (s === "" || s.length > 32 || /\n/.test(s)) return null
  if (/^tel:/i.test(s)) s = s.substring(4)
  if (!/^(\+|0)[0-9 ()\/.\-]+$/.test(s)) return null
  if (/^\d{1,4}[.\/\-]\d{1,2}[.\/\-]\d{1,4}$/.test(s)) return null   // dates
  if (/^0[.,]\d+$/.test(s)) return null                              // 0.5
  var digits = s.replace(/[^0-9]/g, "")
  if (digits.length < 7 || digits.length > 15) return null
  var intl = s.charAt(0) === "+" ? "+" + digits : (/^00/.test(digits) ? "+" + digits.substring(2) : digits)
  return { kind: "phone", target: "tel:" + intl }
}

// Absolute, ~ or file:// path (single line). Whether it exists is checked
// by the caller; returns the expanded path.
function pathCandidate(text, home) {
  var s = String(text || "").trim()
  if (s === "" || s.length > 4096 || /[\n\r\0]/.test(s)) return ""
  if (/^file:\/\//i.test(s)) {
    s = s.replace(/^file:\/\/(localhost)?/i, "")
    try { s = decodeURIComponent(s) } catch (e) { return "" }
  } else if (s === "~" || s.indexOf("~/") === 0) {
    if (!home) return ""
    s = home + s.substring(1)
  }
  if (s.charAt(0) !== "/" || s === "/" || s.indexOf("//") === 0) return ""
  return s.length > 1 && s.charAt(s.length - 1) === "/" ? s.substring(0, s.length - 1) : s
}

// What the file manager opens: a folder itself, a file's parent folder.
function pathOpenTarget(path, type) {
  if (type === "d") return path
  var i = path.lastIndexOf("/")
  return i <= 0 ? "/" : path.substring(0, i)
}

// Colour code: #rgb, #rrggbb, #rrggbbaa, rgb()/rgba(). target is a Qt colour
// string (#aarrggbb for alpha).
function colorTarget(text) {
  var s = String(text || "").trim()
  var m = /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.exec(s)
  var hex2 = function(n) { return ("0" + Math.round(n).toString(16)).slice(-2) }
  if (m) {
    var h = m[1].toLowerCase()
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
    return { kind: "color", target: h.length === 8 ? "#" + h.substring(6) + h.substring(0, 6) : "#" + h, label: s }
  }
  m = /^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*(0|1|0?\.\d+|1\.0+)\s*)?\)$/i.exec(s)
  if (!m) return null
  var r = +m[1], g = +m[2], b = +m[3]
  if (r > 255 || g > 255 || b > 255) return null
  var a = m[4] === undefined ? "" : hex2(parseFloat(m[4]) * 255)
  return { kind: "color", target: "#" + a + hex2(r) + hex2(g) + hex2(b), label: s }
}

// GPS coordinates: decimal "48.21, 16.37" (both with a decimal point, in
// range) or DMS 48°12'30"N 16°22'19"E.
function coordTarget(text) {
  var s = String(text || "").trim()
  if (s.length > 64 || /\n/.test(s)) return null
  var m = /^(-?\d{1,2}\.\d+)\s*[,;]?\s+(-?\d{1,3}\.\d+)$/.exec(s) || /^(-?\d{1,2}\.\d+)\s*[,;]\s*(-?\d{1,3}\.\d+)$/.exec(s)
  if (m) {
    var lat = parseFloat(m[1]), lon = parseFloat(m[2])
    if (Math.abs(lat) > 90 || Math.abs(lon) > 180) return null
    return { kind: "maps", target: m[1] + "," + m[2] }
  }
  var part = "(\\d{1,3})\\s*°\\s*(\\d{1,2})\\s*['′]\\s*(?:(\\d{1,2}(?:\\.\\d+)?)\\s*(?:\"|″|''))?\\s*"
  m = new RegExp("^" + part + "([NS])[\\s,]+" + part + "([EWO])$", "i").exec(s)
  if (!m) return null
  if (+m[1] > 90 || +m[5] > 180 || +m[2] >= 60 || +m[6] >= 60 || (m[3] && +m[3] >= 60) || (m[7] && +m[7] >= 60)) return null
  return { kind: "maps", target: s }
}

// Street address, conservative: 2-4 parts (lines or commas) with a street
// + house number and a postcode + city (AT/DE/CH 4-5 digits, optional
// A-/D-/CH- prefix; US "City, ST 12345"; UK postcode).
var ADDR_L = "A-Za-z\\u00C0-\\u024F"
var ADDR_U = "A-Z\\u00C0-\\u00DE"
var ADDR_STREET_NUM_AFTER = new RegExp("^[" + ADDR_U + "][" + ADDR_L + ".'\\- ]{2,60}\\s\\d{1,4}[a-zA-Z]?(?:\\s?[/\\-]\\s?\\d{1,4}[a-zA-Z]?){0,3}$")
var ADDR_STREET_NUM_BEFORE = new RegExp("^\\d{1,5}[a-zA-Z]?\\s+[" + ADDR_U + "][" + ADDR_L + ".'\\- ]{2,60}$")
var ADDR_DACH_CITY = new RegExp("^(?:(?:A|D|CH)\\s?-\\s?)?\\d{4,5}\\s+[" + ADDR_U + "][" + ADDR_L + ".\\- ]{1,40}$")
var ADDR_US_STATE = /^[A-Z]{2}\s+\d{5}(?:-\d{4})?$/
var ADDR_US_CITYSTATE = new RegExp("^[" + ADDR_U + "][" + ADDR_L + ".\\- ]{1,40}\\s+[A-Z]{2}\\s+\\d{5}(?:-\\d{4})?$")
var ADDR_UK = new RegExp("^(?:[" + ADDR_U + "][" + ADDR_L + ".\\- ]{1,40}\\s+)?[A-Z]{1,2}\\d[A-Z\\d]?\\s?\\d[A-Z]{2}$")
var ADDR_CITY = new RegExp("^[" + ADDR_U + "][" + ADDR_L + ".\\- ]{1,40}$")
function addressTarget(text) {
  var s = String(text || "").trim()
  if (s === "" || s.length > 200 || /[@:#<>{}\[\]=;|$]|https?|www\./i.test(s)) return null
  var parts = s.split(/\s*(?:\n|,)\s*/).filter(function(x) { return x !== "" })
  if (parts.length < 2 || parts.length > 5 || s.split("\n").length > 4) return null
  var street = -1
  for (var i = 0; i < parts.length && street < 0; i++)
    if (ADDR_STREET_NUM_AFTER.test(parts[i]) || ADDR_STREET_NUM_BEFORE.test(parts[i])) street = i
  if (street < 0) return null
  var ok = false
  for (var j = street + 1; j < parts.length && !ok; j++) {
    var q = parts[j]
    if (ADDR_DACH_CITY.test(q) || ADDR_US_CITYSTATE.test(q) || ADDR_UK.test(q)) ok = true
    else if (ADDR_US_STATE.test(q) && j > street + 1 && ADDR_CITY.test(parts[j - 1])) ok = true
  }
  if (!ok) return null
  return { kind: "maps", target: parts.join(", ") }
}

function mapsUrl(query) {
  return "https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(query)
}

// GitHub shorthand owner/repo#123 (GitHub name rules; issues URL, GitHub
// redirects pull requests).
function githubTarget(text) {
  var s = String(text || "").trim()
  var m = /^([A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38})\/([A-Za-z0-9._-]{1,100})#([1-9]\d{0,9})$/.exec(s)
  if (!m || m[2] === "." || m[2] === "..") return null
  return { kind: "github", target: "https://github.com/" + m[1] + "/" + m[2] + "/issues/" + m[3] }
}

// The 4th button for a text row: link/mail, phone, colour, or a path
// candidate (kind "path?" until the caller confirmed it exists).
function rowTarget(text, home) {
  var l = linkTarget(text)
  if (l) return l
  var gh = githubTarget(text)
  if (gh) return gh
  var g = coordTarget(text)
  if (g) return g
  var c = colorTarget(text)
  if (c) return c
  var t = phoneTarget(text)
  if (t) return t
  var p = pathCandidate(text, home)
  if (p) return { kind: "path?", target: p }
  var a = addressTarget(text)
  if (a) return a
  return null
}

// Tooltip for the 4th button.
function targetTooltip(kind, label) {
  if (kind === "mail") return "Send email"
  if (kind === "url") return "Open link"
  if (kind === "phone") return "Call number"
  if (kind === "path") return "Open in file manager"
  if (kind === "maps") return "Open in Maps"
  if (kind === "github") return "Open on GitHub"
  if (kind === "color") return "Colour " + label
  return ""
}

// Esc in the popup: clear a search (the field stays open), else
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
function rowActionNames(armed, phoneOnline, isText, linkKind) {
  if (armed) return ["delete"]
  var out = []
  if (linkKind) out.push("link")
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
    sectionName: sectionName,
    linkTarget: linkTarget,
    phoneTarget: phoneTarget,
    pathCandidate: pathCandidate,
    pathOpenTarget: pathOpenTarget,
    colorTarget: colorTarget,
    rowTarget: rowTarget,
    coordTarget: coordTarget,
    addressTarget: addressTarget,
    mapsUrl: mapsUrl,
    githubTarget: githubTarget,
    targetTooltip: targetTooltip,
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
