// Run: node tests/history.test.js
const assert = require("assert")
const H = require("../ClipboardHistory.js")

let h = []
h = H.addEntry(h, { type: "text", text: "one" }, 3)
h = H.addEntry(h, { type: "text", text: "two" }, 3)
h = H.addEntry(h, { type: "text", text: "three" }, 3)
assert.deepStrictEqual(h.map(e => e.text), ["three", "two", "one"], "newest first")

h = H.addEntry(h, { type: "text", text: "one" }, 3)
assert.deepStrictEqual(h.map(e => e.text), ["one", "three", "two"], "re-copy moves to top, no duplicate")

h = H.togglePinAt(h, 2) // pin "two"
assert.strictEqual(h[2].pinned, true, "pin")
h = H.addEntry(h, { type: "text", text: "four" }, 3)
h = H.addEntry(h, { type: "text", text: "five" }, 3)
assert.ok(h.some(e => e.text === "two" && e.pinned), "pinned survives the limit")
assert.strictEqual(h.filter(e => !e.pinned).length, 3, "limit counts unpinned only")

{
  const before = h.findIndex(e => e.text === "two")
  h = H.addEntry(h, { type: "text", text: "two" }, 3)
  assert.strictEqual(h.filter(e => e.text === "two").length, 1, "no duplicate")
  assert.strictEqual(h.findIndex(e => e.text === "two"), before, "re-copy of a pinned entry keeps its place (drag order)")
  assert.strictEqual(h[before].pinned, true, "re-copy keeps the pin")
  h = H.addEntry(h, { type: "text", text: "two" }, 3) // put it on top for the next checks
  h = [h[before]].concat(h.filter((e, i) => i !== before))
}

let rows = H.displayRows(h, "", 50)
assert.strictEqual(rows[0].pinned, true, "pinned rows first")
assert.strictEqual(rows[0].slot, 1)
assert.strictEqual(rows[1].pinned, false)
assert.strictEqual(rows[1].slot, 2, "slots run top to bottom: history continues after the pinned rows")

rows = H.displayRows(h, "F.VE", 50)
assert.deepStrictEqual(rows.map(r => r.previewText), ["five"], "case-insensitive regex")
rows = H.displayRows(h, "(", 50)
assert.deepStrictEqual(rows, [], "invalid regex falls back to plain text")
rows = H.displayRows([{ type: "text", text: "c++ (x)" }], "c++ (", 50)
assert.strictEqual(rows.length, 1, "plain text match with regex chars")

let cleared = H.clearHistory(h)
assert.deepStrictEqual(cleared.map(e => e.text), ["two"], "clear keeps pinned")

let removed = H.removeEntryAt(h, 0)
assert.ok(!removed.some(e => e.text === "two"), "delete removes even pinned")

assert.strictEqual(H.parseEntryJson('{"type":"text","text":"   "}'), null, "blank ignored")
assert.deepStrictEqual(H.parseHistory("not json"), [], "broken file -> empty")
assert.deepStrictEqual(H.parseHistory('[{"type":"text","text":"a","pinned":true},"b"]'),
  [{ type: "text", text: "a", pinned: true }, { type: "text", text: "b" }], "stock format imports")

let f = H.displayRows([{ type: "text", text: "file:///home/x/a%20b.png\n" }], "", 5)
assert.strictEqual(f[0].entryType, "file")
assert.strictEqual(f[0].previewText, "a b.png")
let mixed = H.displayRows([{ type: "text", text: "see file:///etc/hosts\nnot a file" }], "", 5)
assert.strictEqual(mixed[0].entryType, "text", "mixed text is not a file list")

let big = "x".repeat(20000)
let br = H.displayRows([{ type: "text", text: big }], "", 5)
assert.ok(br[0].fullText.length <= 8192, "display capped")

let img = H.addEntry([], { type: "image", path: "/tmp/a.png", mime: "image/png", capturedAt: "Saturday 07:00" }, 5)
assert.strictEqual(H.displayRows(img, "image", 5).length, 1, "images searchable")

// Search field keys: text-field shortcuts must reach the field ("").
const K = H.KEY
const act = (key, mods = {}) => H.searchKeyAction(Object.assign({ key, ctrl: false, alt: false, shift: false, hasSelection: false }, mods))
assert.strictEqual(act(K.A, { ctrl: true }), "", "Ctrl+A selects all in the field")
assert.strictEqual(act(K.C, { ctrl: true, hasSelection: true }), "copySelection", "Ctrl+C copies the selected search text")
assert.strictEqual(act(K.Insert, { ctrl: true, hasSelection: true }), "copySelection", "Ctrl+Insert copies too")
assert.strictEqual(act(K.C, { ctrl: true }), "", "Ctrl+C without a selection is left to the field")
assert.strictEqual(act(K.X, { ctrl: true, hasSelection: true }), "cutSelection", "Ctrl+X cuts the selected search text")
assert.strictEqual(act(K.V, { ctrl: true }), "", "Ctrl+V pastes into the field")
assert.strictEqual(act(0x01000003, { ctrl: true }), "", "Ctrl+Backspace deletes a word")
assert.strictEqual(act(0x01000003), "", "Backspace edits")
assert.strictEqual(act(0x5a, { ctrl: true }), "", "Ctrl+Z undoes")
for (const k of [K.Left, K.Right, K.Up, K.Down, K.Home, K.End])
  assert.strictEqual(act(k, { shift: true }), "", "Shift+arrow/Home/End selects text: " + k)
for (const k of [K.Left, K.Right]) assert.strictEqual(act(k), "", "Left/Right move the text cursor")
assert.strictEqual(act(K.Up), "up")
assert.strictEqual(act(K.Down), "down")
assert.strictEqual(act(K.K, { ctrl: true }), "up")
assert.strictEqual(act(K.J, { ctrl: true }), "down")
assert.strictEqual(act(K.Home), "home")
assert.strictEqual(act(K.End), "end")
assert.strictEqual(act(K.PageDown), "pageDown")
assert.strictEqual(act(K.Return), "enter")
assert.strictEqual(act(K.Return, { shift: true }), "enter")
assert.strictEqual(act(K.Escape), "escape")
assert.strictEqual(act(0x33, { alt: true }), "slot", "Alt+3 = third row from the top")
assert.strictEqual(act(0x33, { ctrl: true }), "", "Ctrl+3 is no longer a shortcut")
assert.strictEqual(act(K.P, { ctrl: true }), "pin", "Ctrl+P pins")
assert.strictEqual(act(K.F, { ctrl: true }), "pin", "Ctrl+F still pins")
assert.strictEqual(act(K.I, { ctrl: true }), "private", "Ctrl+I toggles incognito")
assert.strictEqual(act(K.Delete), "delete", "Del removes the entry")
assert.strictEqual(act(K.Delete, { hasSelection: true }), "", "Del with selected search text deletes the text")
assert.strictEqual(act(K.Delete, { shift: true }), "clear")
assert.strictEqual(act(0x61), "", "typing goes to the field")
assert.strictEqual(act(K.U, { ctrl: true }), "clearSearch", "Ctrl+U clears the search without touching the clipboard")

// ---- 1.3.0 ------------------------------------------------------------------
// 4: Ctrl+N / Alt+N find the row and paste on modifier release
{
  const rows = H.displayRows([{ type: "text", text: "a", pinned: true }, { type: "text", text: "b" }, { type: "text", text: "c" }], "", 50)
  assert.deepStrictEqual(rows.map(r => r.slot), [1, 2, 3], "Alt+1..3 top to bottom, pinned first")
  assert.strictEqual(H.slotRowIndex(rows, 1), 0, "Alt+1 = pinned row on top")
  assert.strictEqual(H.slotRowIndex(rows, 2), 1, "Alt+2 = first history row")
  assert.strictEqual(H.slotRowIndex(rows, 3), 2)
  assert.strictEqual(H.slotRowIndex(rows, 4), -1, "no fourth row")
  for (const k of [K.Control, K.Alt, K.Shift, K.Meta]) assert.ok(H.isModifierKey(k), "modifier " + k)
  assert.ok(!H.isModifierKey(0x31), "digit is not a modifier")
  assert.strictEqual(act(K.S, { ctrl: true }), "send", "Ctrl+S sends to the phone")
}
// 5: pinned rows need a second Del
assert.strictEqual(H.deleteAction(false, false), "delete", "unpinned: delete at once")
assert.strictEqual(H.deleteAction(true, false), "arm", "pinned: first Del arms")
assert.strictEqual(H.deleteAction(true, true), "delete", "pinned + armed: second Del deletes")
// 6: count label
assert.strictEqual(H.countLabel(119, 3, 119, false), "119 items", "1.5.0: no pinned part")
assert.strictEqual(H.countLabel(119, 0, 119, false), "119 items", "no pinned part when 0")
assert.strictEqual(H.countLabel(1, 0, 1, false), "1 item", "singular")
assert.strictEqual(H.countLabel(0, 0, 0, false), "0 items")
assert.strictEqual(H.countLabel(119, 3, 4, true), "4 of 119 items", "while searching")
assert.strictEqual(H.pinnedCount([{ pinned: true }, {}, { pinned: true }]), 2)
// 2: popup scale
assert.strictEqual(H.popupScale(1080), 1, "24in 1080p unchanged")
assert.strictEqual(H.popupScale(1440), 1, "bigger screens unchanged")
assert.strictEqual(H.popupScale(750), 0.85, "small laptop screen (1200x750 logical) 15% smaller")
assert.strictEqual(H.popupScale(1000), 1000 / 1080, "in between: proportional")
// 9: Flux origin
{
  const st = { clipboard: [{ dir: "in", text: "hello", time: 1000 }, { dir: "out", text: "mine", time: 1000 }],
               devices: [{ paired: true, online: true }] }
  assert.strictEqual(H.fluxOrigin(st, "hello", 1005), "phone")
  assert.strictEqual(H.fluxOrigin(st, "mine", 1005), "", "own copies are not from the phone")
  assert.strictEqual(H.fluxOrigin(st, "hello", 2000), "", "old incoming copy does not count")
  assert.strictEqual(H.fluxOrigin(null, "hello", 1005), "")
  assert.ok(H.fluxPhoneOnline(st))
  assert.ok(!H.fluxPhoneOnline({ devices: [{ paired: true, online: false }] }))
  assert.strictEqual(H.fluxPhoneName({ devices: [{ paired: true, online: false, name: "A" }, { paired: true, online: true, name: "B" }] }), "B")
  assert.strictEqual(H.fluxPhoneName({ devices: [] }), "")
  assert.strictEqual(H.fluxLastSync(st), 1000)
  assert.strictEqual(H.fluxLastSync({}), 0)
  assert.strictEqual(H.agoLabel(0, 5), "never")
  assert.strictEqual(H.agoLabel(1000, 1030), "just now")
  assert.strictEqual(H.agoLabel(1000, 1000 + 300), "5 min ago")
  assert.strictEqual(H.agoLabel(1000, 1000 + 7200), "2 h ago")
  assert.strictEqual(H.agoLabel(1000, 1000 + 3 * 86400), "3 d ago")
  assert.strictEqual(H.phoneIconState("running", true), "online")
  assert.strictEqual(H.phoneIconState("running", false), "nophone")
  assert.strictEqual(H.phoneIconState("absent", true), "", "hidden without Flux")
  assert.strictEqual(H.phoneIconState("", false), "", "hidden before the first check")
  assert.strictEqual(H.phoneIconState("paused", false), "paused", "incognito pauses Flux")
  assert.strictEqual(H.phoneIconState("off", false), "off")
  assert.strictEqual(H.phoneTooltip("online", "Pixel"), "Pixel connected via Flux")
  assert.strictEqual(H.phoneTooltip("nophone", ""), "No phone connected")
  assert.strictEqual(H.phoneTooltip("paused", ""), "Flux paused (incognito)")
  assert.strictEqual(H.phoneTooltip("off", ""), "Flux not running")
  const h = H.setOrigin([{ type: "text", text: "hello" }], "hello", "phone")
  assert.strictEqual(H.parseHistory(JSON.stringify(h))[0].origin, "phone", "origin survives save/load")
  assert.strictEqual(H.displayRows(h, "", 5)[0].fromPhone, true)
  assert.strictEqual(H.addEntry(h, { type: "text", text: "hello" }, 50)[0].origin, undefined, "a local re-copy is not from the phone")
}

// 1.3.1: touchpad momentum
assert.strictEqual(H.kineticVelocity(0, 30, 150), 200, "first delta after a pause: instant speed")
assert.strictEqual(H.kineticVelocity(1000, 30, 200), 150, "a long pause starts over")
assert.strictEqual(Math.round(H.kineticVelocity(3000, 20, 10)), 2600, "smoothed")
assert.strictEqual(H.kineticFlickVelocity(2600, 16), 2600, "fingers lifted while moving: flick")
assert.strictEqual(H.kineticFlickVelocity(2600, 200), 0, "fingers stopped before lifting: no flick")
assert.strictEqual(H.kineticFlickVelocity(100, 10), 0, "slow drag: no flick")

// 1.4.0: action order phone, trash, pin (pin rightmost, never moves)
assert.deepStrictEqual(H.rowActionNames(false, true, true), ["send", "delete", "pin"])
assert.deepStrictEqual(H.rowActionNames(false, false, true), ["delete", "pin"], "no phone: no send")
assert.deepStrictEqual(H.rowActionNames(false, true, false), ["delete", "pin"], "images are not sent")
assert.deepStrictEqual(H.rowActionNames(true, true, true), ["delete"], "armed delete: only trash")

// 1.3.2: row actions by keyboard
{
  const st = (f, n, key, extra) => H.actionFocusStep(f, n, Object.assign({ key: key, ctrl: false, alt: false, shift: false, atTextEnd: true }, extra || {}))
  assert.deepStrictEqual(st(-1, 3, K.Right), { focus: 0, consumed: true, trigger: false }, "Right enters the actions")
  assert.deepStrictEqual(st(-1, 3, K.Right, { atTextEnd: false }), { focus: -1, consumed: false, trigger: false }, "Right inside the search text moves the text cursor")
  assert.strictEqual(st(0, 3, K.Right).focus, 1)
  assert.strictEqual(st(2, 3, K.Right).focus, 2, "stops at the last action")
  assert.deepStrictEqual(st(0, 3, K.Left), { focus: -1, consumed: true, trigger: false }, "Left from the first action returns to the row")
  assert.strictEqual(st(-1, 3, K.Left).consumed, false, "Left on the row edits the search")
  assert.deepStrictEqual(st(1, 3, K.Return), { focus: 1, consumed: true, trigger: true }, "Enter triggers the focused action")
  assert.strictEqual(st(-1, 3, K.Return).consumed, false, "Enter on the row pastes as usual")
  assert.deepStrictEqual(st(1, 3, K.Escape), { focus: -1, consumed: true, trigger: false }, "Esc returns to the row")
  assert.deepStrictEqual(st(1, 3, K.Down), { focus: -1, consumed: false, trigger: false }, "Down returns to the row and moves")
  assert.strictEqual(st(1, 3, K.Return, { shift: true }).trigger, false, "Shift+Enter is not an action press")
  assert.strictEqual(st(-1, 0, K.Right).focus, -1, "no actions: nothing to focus")
}

// clear button label
assert.strictEqual(H.clearLabelText(162, true), "󰩺  Clear history (162 items)")
assert.strictEqual(H.clearLabelText(162, false), "󰩺  Clear history (162)")
assert.strictEqual(H.clearLabelText(1, true), "󰩺  Clear history (1 item)")
assert.strictEqual(H.clearLabelText(-3, false), "󰩺  Clear history (0)")
assert.strictEqual(H.clearLabel(162, 200, 230, 24), "󰩺  Clear history (162 items)", "fits with gap")
assert.strictEqual(H.clearLabel(162, 200, 220, 24), "󰩺  Clear history (162)", "too tight: short")
assert.strictEqual(H.clearLabel(162, 200, 224, 24), "󰩺  Clear history (162 items)", "exact fit")

console.log("history tests: all passed")

// ---- drag reorder of pinned entries ----------------------------------------
{
  let g = [
    { type: "text", text: "a", pinned: true }, { type: "text", text: "x" },
    { type: "text", text: "b", pinned: true }, { type: "text", text: "c", pinned: true }
  ]
  const r = H.reorderPinned(g, [3, 0, 2]) // drag "c" to the top
  assert.deepStrictEqual(r.map(e => e.text), ["c", "x", "a", "b"], "pinned order follows the drag, unpinned stay")
  const rows = H.displayRows(r, "", 9)
  assert.deepStrictEqual(rows.map(x => x.slot + ":" + x.previewText), ["1:c", "2:a", "3:b", "4:x"], "Alt+N follows the new order")
  assert.deepStrictEqual(H.reorderPinned(g, [1, 0, 2]).map(e => e.text), ["a", "x", "b", "c"], "refuses unpinned index")
  assert.deepStrictEqual(H.reorderPinned(g, [0, 0, 2]).map(e => e.text), ["a", "x", "b", "c"], "refuses duplicates")
  const saved = H.parseHistory(JSON.stringify(r))
  assert.deepStrictEqual(saved.map(e => e.text), ["c", "x", "a", "b"], "order survives save/load")
  const again = H.addEntry(r, { type: "text", text: "a" }, 50)
  assert.deepStrictEqual(again.filter(e => e.pinned).map(e => e.text), ["c", "a", "b"], "re-copy keeps the dragged order")
  console.log("drag reorder: ok")
}

// ---- collapsible search header (1.9.0) -------------------------------------
assert.strictEqual(H.escapeAction("abc", true), "clear", "Esc clears a search first")
assert.strictEqual(H.escapeAction("", true), "collapse", "then collapses the empty field")
assert.strictEqual(H.escapeAction("", false), "close", "then closes the popup")
assert.strictEqual(H.searchShown("", false), false, "collapsed: title + search button")
assert.strictEqual(H.searchShown("", true), true, "button click expands")
assert.strictEqual(H.searchShown("x", false), true, "typing expands")
console.log("search header: ok")

// ---- 1.11.0 headings --------------------------------------------------------
assert.strictEqual(H.sectionName(true, 2, true, 5), "Results · 5", "searching: one Results heading")
assert.strictEqual(H.sectionName(false, 2, true, 5), "Results · 5")
assert.strictEqual(H.sectionName(true, 2, false, 9), "Pinned")
assert.strictEqual(H.sectionName(false, 2, false, 9, Date.now()), "History")
assert.strictEqual(H.sectionName(false, 0, false, 9, Date.now()), "", "no pins: no heading")
console.log("headings: ok")

// ---- 1.12.0 link / e-mail detection ---------------------------------------
{
  const L = H.linkTarget
  assert.deepStrictEqual(L("https://example.com/a?b=1"), { kind: "url", target: "https://example.com/a?b=1" })
  assert.deepStrictEqual(L("  http://x.org  "), { kind: "url", target: "http://x.org" }, "trimmed")
  assert.deepStrictEqual(L("www.example.com"), { kind: "url", target: "https://www.example.com" })
  assert.deepStrictEqual(L("roehrbacher.com"), { kind: "url", target: "https://roehrbacher.com" }, "bare domain")
  assert.deepStrictEqual(L("sub.example.at/path#x"), { kind: "url", target: "https://sub.example.at/path#x" })
  assert.deepStrictEqual(L("timon@roehrbacher.com"), { kind: "mail", target: "mailto:timon@roehrbacher.com" })
  assert.deepStrictEqual(L("mailto:a.b@x.de"), { kind: "mail", target: "mailto:a.b@x.de" })
  for (const f of ["notes.txt", "script.sh", "main.py", "README.md", "photo.png", "archive.zip", "a.b", "1.5", "v1.2.3", "file.json", "x.pdf"])
    assert.strictEqual(L(f), null, "not a link: " + f)
  for (const f of ["", "hello world", "https://x.com\nmore", "look at example.com", "user@host", "www.com", "ftp://x.com", "@x.com"])
    assert.strictEqual(L(f), null, "not a link: " + JSON.stringify(f))
  assert.deepStrictEqual(H.rowActionNames(false, true, true, "url"), ["link", "send", "delete", "pin"], "link button first (left)")
  assert.deepStrictEqual(H.rowActionNames(false, false, true, ""), ["delete", "pin"])
  assert.deepStrictEqual(H.rowActionNames(true, true, true, "url"), ["delete"], "armed: only trash")
  console.log("links: ok")
}

// ---- 1.13.0 phone / path / colour detection -------------------------------
{
  const P = H.phoneTarget
  assert.deepStrictEqual(P("+43 664 1234567"), { kind: "phone", target: "tel:+436641234567" })
  assert.deepStrictEqual(P("0043 (664) 123-45-67"), { kind: "phone", target: "tel:+436641234567" })
  assert.deepStrictEqual(P("0664/1234567"), { kind: "phone", target: "tel:06641234567" })
  assert.deepStrictEqual(P("01 5131234"), { kind: "phone", target: "tel:015131234" })
  assert.deepStrictEqual(P("tel:+4915112345678"), { kind: "phone", target: "tel:+4915112345678" })
  for (const f of ["123456", "0664 12", "01.02.2026", "2026-10-22", "12345678", "0.5", "+43 abc 123", "0664 1234567 and more", "+1234567890123456"])
    assert.strictEqual(P(f), null, "not a phone: " + f)
  const C = H.pathCandidate
  assert.strictEqual(C("/etc/hosts", "/home/t"), "/etc/hosts")
  assert.strictEqual(C("~/Work/", "/home/t"), "/home/t/Work")
  assert.strictEqual(C("~", "/home/t"), "/home/t")
  assert.strictEqual(C("file:///home/t/My%20File.txt", "/home/t"), "/home/t/My File.txt")
  assert.strictEqual(C("/home/t/with space", "/home/t"), "/home/t/with space")
  for (const f of ["relative/path", "/", "//share", "/a\n/b", "~user/x", "http://x.com/a", ""])
    assert.strictEqual(C(f, "/home/t"), "", "not a path: " + JSON.stringify(f))
  assert.strictEqual(H.pathOpenTarget("/home/t/a.txt", "f"), "/home/t", "file: parent folder")
  assert.strictEqual(H.pathOpenTarget("/home/t/Work", "d"), "/home/t/Work", "folder: itself")
  assert.strictEqual(H.pathOpenTarget("/x", "f"), "/")
  const K = H.colorTarget
  assert.deepStrictEqual(K("#ff8800"), { kind: "color", target: "#ff8800", label: "#ff8800" })
  assert.deepStrictEqual(K("#F80"), { kind: "color", target: "#ff8800", label: "#F80" })
  assert.deepStrictEqual(K("#ff880080"), { kind: "color", target: "#80ff8800", label: "#ff880080" }, "Qt #aarrggbb")
  assert.deepStrictEqual(K("rgb(255, 136, 0)"), { kind: "color", target: "#ff8800", label: "rgb(255, 136, 0)" })
  assert.deepStrictEqual(K("rgba(255,136,0,0.5)"), { kind: "color", target: "#80ff8800", label: "rgba(255,136,0,0.5)" })
  for (const f of ["#ff88", "#ggg", "rgb(256,0,0)", "ff8800", "#ff8800 text"])
    assert.strictEqual(K(f), null, "not a colour: " + f)
  const R = H.rowTarget
  assert.strictEqual(R("https://x.org", "/h").kind, "url")
  assert.strictEqual(R("#abc", "/h").kind, "color")
  assert.strictEqual(R("+43 1 5131234", "/h").kind, "phone")
  assert.deepStrictEqual(R("~/x", "/h"), { kind: "path?", target: "/h/x" })
  assert.strictEqual(R("hello", "/h"), null)
  assert.strictEqual(H.targetTooltip("url"), "Open link")
  assert.strictEqual(H.targetTooltip("mail"), "Send email")
  assert.strictEqual(H.targetTooltip("phone"), "Call number")
  assert.strictEqual(H.targetTooltip("path"), "Open in file manager")
  assert.strictEqual(H.targetTooltip("color", "#ff8800"), "Colour #ff8800")
  console.log("phone/path/colour: ok")
}

// ---- 1.13.0 maps / GitHub detection ----------------------------------------
{
  const G = H.coordTarget
  assert.deepStrictEqual(G("48.21, 16.37"), { kind: "maps", target: "48.21,16.37" })
  assert.deepStrictEqual(G("-33.8688 151.2093"), { kind: "maps", target: "-33.8688,151.2093" })
  assert.strictEqual(G(`48°12'30"N 16°22'19"E`).kind, "maps")
  assert.strictEqual(G("48° 12′ 30.5″ N, 16° 22′ 19″ E").kind, "maps")
  for (const f of ["1, 2", "48, 16", "95.1, 16.3", "48.2, 190.5", "1.5", "v1.2 3.4", `48°72'N 16°22'E`, "48.21, 16.37 x"])
    assert.strictEqual(G(f), null, "not coords: " + f)
  const A = H.addressTarget
  const yes = {
    "Neubaugasse 12, 1070 Wien": "Neubaugasse 12, 1070 Wien",
    "Hauptstraße 5/2/7\nA-3032 Eichgraben": "Hauptstraße 5/2/7, A-3032 Eichgraben",
    "Musterweg 3a, D-80331 München, Deutschland": "Musterweg 3a, D-80331 München, Deutschland",
    "Bahnhofstrasse 1, 8001 Zürich": "Bahnhofstrasse 1, 8001 Zürich",
    "1600 Amphitheatre Pkwy, Mountain View, CA 94043": "1600 Amphitheatre Pkwy, Mountain View, CA 94043",
    "350 Fifth Avenue\nNew York NY 10118": "350 Fifth Avenue, New York NY 10118",
    "10 Downing Street, London SW1A 2AA": "10 Downing Street, London SW1A 2AA",
    "221B Baker Street\nLondon\nNW1 6XE": "221B Baker Street, London, NW1 6XE",
  }
  for (const [k, v] of Object.entries(yes)) assert.deepStrictEqual(A(k), { kind: "maps", target: v }, "address: " + k)
  for (const f of ["Neubaugasse 12", "1070 Wien", "Room 12, 1070 items", "version 2, 2026 release notes are long", "call me at 5, 1234 times",
                   "Hello there 12, see you", "a,b,c,d,e,f,g", "Neubaugasse 12, 1070 Wien\nhttps://x.com", "Order 12345 Item 4, 1000 Stück=3"])
    assert.strictEqual(A(f), null, "not an address: " + JSON.stringify(f))
  assert.strictEqual(H.mapsUrl("Neubaugasse 12, 1070 Wien"), "https://www.google.com/maps/search/?api=1&query=Neubaugasse%2012%2C%201070%20Wien")
  const GH = H.githubTarget
  assert.deepStrictEqual(GH("roehrbacher/omarchy-clipboard#12"), { kind: "github", target: "https://github.com/roehrbacher/omarchy-clipboard/issues/12" })
  assert.strictEqual(GH("a-b/c.d_e#1").target, "https://github.com/a-b/c.d_e/issues/1")
  for (const f of ["-ab/repo#1", "ab-/repo#1", "a--b/repo#1", "owner/repo#0", "owner/repo #1", "owner/repo#", "owner/re po#1", "o/r/x#1", "owner/..#1", "a".repeat(40) + "/r#1", "#12", "owner#12"])
    assert.strictEqual(GH(f), null, "not GitHub: " + f)
  assert.strictEqual(H.rowTarget("owner/repo#5", "/h").kind, "github")
  assert.strictEqual(H.rowTarget("48.21, 16.37", "/h").kind, "maps")
  assert.strictEqual(H.rowTarget("Neubaugasse 12, 1070 Wien", "/h").kind, "maps")
  assert.strictEqual(H.targetTooltip("maps"), "Open in Maps")
  assert.strictEqual(H.targetTooltip("github"), "Open on GitHub")
  console.log("maps/github: ok")
}

{
  // 1.13.1: image file size
  assert.strictEqual(H.formatBytes(0), "")
  assert.strictEqual(H.formatBytes(812), "812 B")
  assert.strictEqual(H.formatBytes(250880), "245 KB")
  assert.strictEqual(H.formatBytes(1468006), "1.4 MB")
  assert.strictEqual(H.formatBytes(25 * 1024 * 1024), "25 MB")
  const img = H.normalizeEntry({ type: "image", path: "/x/a.png", mime: "image/png", capturedAt: "Thursday 20:40", bytes: 250880, screenshot: true })
  assert.strictEqual(img.bytes, 250880)
  assert.strictEqual(H.previewText(img), "Screenshot · 245 KB")
  assert.strictEqual(H.previewText(H.normalizeEntry({ type: "image", path: "/x/b.png", mime: "image/png", capturedAt: "Thursday 20:40" })), "Image", "old entries: no size, generic Image")
  assert.strictEqual(H.normalizeEntry({ type: "image", path: "/x/c.png", bytes: "junk" }).bytes, undefined)
  console.log("image size: ok")
}

{
  // 1.13.2: only real screenshots are labelled "Screenshot"
  const web = H.normalizeEntry({ type: "image", path: "/x/w.png", mime: "image/png", capturedAt: "Thursday 20:51", bytes: 76593, screenshot: false })
  assert.strictEqual(web.screenshot, undefined)
  assert.strictEqual(H.previewText(web), "Image · 75 KB")
  const shot = H.normalizeEntry({ type: "image", path: "/x/s.png", mime: "image/png", capturedAt: "Thursday 20:52", screenshot: true })
  assert.strictEqual(H.previewText(shot), "Screenshot")
  let hh = H.addEntry([], shot, 10)
  assert.strictEqual(hh[0].screenshot, true, "flag survives addEntry")
  console.log("screenshot label: ok")
}

{
  // 1.13.3: search over image rows
  const hist = [
    { type: "image", path: "/x/s.png", mime: "image/png", capturedAt: "Thursday 20:52", bytes: 76593, screenshot: true },
    { type: "image", path: "/x/w.png", mime: "image/png", capturedAt: "Thursday 20:51", bytes: 250880 },
    { type: "text", text: "hello" }
  ]
  const q = s => H.displayRows(hist, s, 50).map(r => r.previewText)
  assert.deepStrictEqual(q("screenshot"), ["Screenshot · 75 KB"], "only real screenshots")
  assert.deepStrictEqual(q("image"), ["Screenshot · 75 KB", "Image · 245 KB"], "all images")
  assert.deepStrictEqual(q("245 kb"), ["Image · 245 KB"], "by size")
  assert.deepStrictEqual(q("thursday"), ["Screenshot · 75 KB", "Image · 245 KB"], "copy day still searchable")
  console.log("image search: ok")
}

{
  // 1.14.0: day headings
  const now = new Date(2026, 9, 22, 21, 0).getTime()
  const D = (y, m, d, h) => new Date(y, m, d, h || 12).getTime()
  assert.strictEqual(H.dayLabel(D(2026, 9, 22, 0), now), "today")
  assert.strictEqual(H.dayLabel(D(2026, 9, 21, 23), now), "Yesterday")
  assert.strictEqual(H.dayLabel(D(2026, 9, 20), now), "Tue 20 Oct")
  assert.strictEqual(H.dayLabel(D(2026, 8, 30), now), "Wed 30 Sep")
  assert.strictEqual(H.dayLabel(0, now), "Earlier")
  assert.strictEqual(H.dayLabel(undefined, now), "Earlier")
  const S = H.sectionName
  assert.strictEqual(S(false, 1, false, 5, D(2026, 9, 22), now, false), "History", "today under History with pins")
  assert.strictEqual(S(false, 0, false, 5, D(2026, 9, 22), now, false), "", "no pins, one day: no heading (as before)")
  assert.strictEqual(S(false, 0, false, 5, D(2026, 9, 22), now, true), "History", "no pins but older days: History")
  assert.strictEqual(S(false, 0, false, 5, D(2026, 9, 21), now, true), "Yesterday")
  assert.strictEqual(S(true, 1, false, 5, D(2026, 9, 20), now, true), "Pinned", "no day headings in Pinned")
  assert.strictEqual(S(false, 1, true, 3, D(2026, 9, 20), now, true), "Results · 3", "no day headings while searching")
  const hist = [
    { type: "text", text: "p", pinned: true, at: D(2026, 9, 10) },
    { type: "text", text: "a", at: D(2026, 9, 22) },
    { type: "text", text: "b", at: D(2026, 9, 21) },
    { type: "text", text: "c" }
  ]
  const rows = H.displayRows(hist, "", 50)
  assert.deepStrictEqual(rows.map(r => r.at > 0), [true, true, true, false], "copy time reaches the rows")
  assert.strictEqual(H.spansDays(rows, now), true)
  assert.strictEqual(H.spansDays(rows.slice(0, 2), now), false, "pins don't count")
  assert.strictEqual(H.normalizeEntry({ type: "text", text: "x", at: 123 }).at, 123, "at persists")
  assert.strictEqual(H.normalizeEntry({ type: "text", text: "x", at: "junk" }).at, undefined)
  const big = H.displayRows([{ type: "text", text: "y".repeat(20000), at: 5 }], "", 5)
  assert.strictEqual(big[0].at, 5, "capped rows keep their time")
  console.log("day headings: ok")
}
