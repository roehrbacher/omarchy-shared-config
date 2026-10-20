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

h = H.addEntry(h, { type: "text", text: "two" }, 3)
assert.strictEqual(h[0].text, "two")
assert.strictEqual(h[0].pinned, true, "re-copy keeps the pin")

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
assert.strictEqual(H.displayRows(img, "screenshot", 5).length, 1, "images searchable")

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

console.log("history tests: all passed")
