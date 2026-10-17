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
assert.strictEqual(rows[1].slot, 1, "history slots restart at 1")

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
assert.strictEqual(act(0x33, { ctrl: true }), "slot", "Ctrl+3")
assert.strictEqual(act(0x33, { alt: true }), "pinnedSlot", "Alt+3")
assert.strictEqual(act(K.F, { ctrl: true }), "pin")
assert.strictEqual(act(K.P, { ctrl: true }), "private")
assert.strictEqual(act(K.Delete), "delete", "Del removes the entry")
assert.strictEqual(act(K.Delete, { hasSelection: true }), "", "Del with selected search text deletes the text")
assert.strictEqual(act(K.Delete, { shift: true }), "clear")
assert.strictEqual(act(0x61), "", "typing goes to the field")
assert.strictEqual(act(K.U, { ctrl: true }), "clearSearch", "Ctrl+U clears the search without touching the clipboard")

console.log("history tests: all passed")
