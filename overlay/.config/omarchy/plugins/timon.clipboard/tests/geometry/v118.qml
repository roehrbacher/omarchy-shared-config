import Quickshell
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Ui
// 1.18.0 on the real Clipboard.qml: QR previews + tooltips, OCR tooltips,
// "Click action" setting, search filter rows fit, drag between Pinned and
// History (no flicker: the dragged row keeps its delegate, one step at a time).
ShellRoot {
  id: shell
  property var clip: null
  function find(item, name, out) {
    if (!item) return
    if (item.objectName === name && out.indexOf(item) < 0) out.push(item)
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) find(kids[i], name, out)
    if (item.contentItem && item.contentItem !== item) find(item.contentItem, name, out)
  }
  Window { id: win; width: 700; height: 900; visible: true }
  Component.onCompleted: {
    var c = Qt.createComponent("clip/Clipboard.qml")
    if (c.status !== Component.Ready) { console.log("QUE ERR " + c.errorString()); Qt.quit(); return }
    clip = c.createObject(win.contentItem, {})
    clip.open("{}")
    t.start()
  }
  Timer { id: t; interval: 3000; onTriggered: shell.run() }
  Timer { id: t2; interval: 600; onTriggered: shell.check() }
  Timer { id: t3; interval: 900; onTriggered: shell.check2() }
  Timer { id: t4; interval: 900; onTriggered: shell.settings() }
  Timer { id: t5; interval: 1500; onTriggered: { console.log("QUE end opened=" + clip.opened); Qt.quit() } }
  function run() {
    var now = Date.now()
    clip.history = [
      { type: "text", text: "pin A", pinned: true, at: now },
      { type: "text", text: "pin B", pinned: true, at: now },
      { type: "image", path: "/nonexistent/w.png", mime: "image/png", bytes: 900, at: now, qr: "WIFI:T:WPA;S:ExampleNet;P:not-a-real-pass;;", scanned: true, scanv: 2 },
      { type: "image", path: "/nonexistent/u.png", mime: "image/png", bytes: 900, at: now, qr: "https://example.com/menu", scanned: true, scanv: 2 },
      { type: "image", path: "/nonexistent/m.png", mime: "image/png", bytes: 900, at: now, qr: "mailto:someone@example.org", scanned: true, scanv: 2 },
      { type: "image", path: "/nonexistent/t.png", mime: "image/png", bytes: 900, at: now, qr: "Locker 12, code 0000", scanned: true, scanv: 2 },
      { type: "image", path: "/nonexistent/s.png", mime: "image/png", bytes: 900, at: now, screenshot: true, ocr: "Invoice", scanned: true, scanv: 2 },
      { type: "image", path: "/nonexistent/i.png", mime: "image/png", bytes: 900, at: now, ocr: "Menu", scanned: true, scanv: 2 },
      { type: "text", text: "hist one", at: now - 1000 },
      { type: "text", text: "hist two", at: now - 2000 }
    ]
    clip.rebuildDisplay(false)
    clip.cursorActive = true
    t2.start()
  }
  function rowsNow() {
    var list = []; for (var w = 0; w < clip.children.length; w++) find(clip.children[w], "resultList", list)
    var rows = []; find(list[0], "clipRow", rows); return rows.sort(function(a, b) { return a.index - b.index })
  }
  function acts(row) { var a = []; find(row, "clipAction", a); return a.filter(function(x) { return x.visible && x.parent.visible }).map(function(x) { return x.tooltipText }).join(",") }
  function order() { var o = []; for (var i = 0; i < clip.displayModelCount(); i++) o.push((clip.history[clip.displayModelGet(i).historyIndex].text || "img") + (clip.displayModelGet(i).pinned ? "*" : "")); return o.join(" ") }
  function check() {
    var rows = rowsNow()
    for (var i = 2; i < 8 && i < rows.length; i++) { clip.selectedIndex = rows[i].index; console.log("QUE preview '" + rows[i].previewText + "' actions=[" + acts(rows[i]) + "]") }
    // drag "hist one" (index 8) up into Pinned slot 1, step by step
    var row8 = rowsNow()[8]
    clip.dragStart(8)
    var steps = []
    for (var tgt = 7; tgt >= 1; tgt--) { clip.dragMoveTo(tgt); steps.push(clip.dragRow + (clip.displayModelGet(clip.dragRow).pinned ? "p" : "h")) }
    var sameDelegate = rowsNow().indexOf(row8) >= 0 && row8.previewText === "hist one"
    console.log("QUE drag up steps=" + steps.join(",") + " sameDelegate=" + sameDelegate)
    clip.dragFinish()
    console.log("QUE after drop: " + order())
    // drag pinned "pin B" (now index 2) down into History: unpinned on drop
    clip.dragStart(2)
    steps = []
    for (var d = 3; d <= 6; d++) { clip.dragMoveTo(d); steps.push(clip.dragRow + (clip.displayModelGet(clip.dragRow).pinned ? "p" : "h")) }
    console.log("QUE drag down steps=" + steps.join(","))
    clip.dragFinish()
    console.log("QUE after drop: " + order())
    // Click action: copy only
    clip.setClickAction("copy")
    clip.clickIndex(clip.displayModelCount() - 1)
    console.log("QUE copy-click opened=" + clip.opened + " clickAction=" + clip.clickAction)
    t3.start()
  }
  function check2() {
    clip.setClickAction("paste")
    clip.infoOpen = true
    t4.start()
  }
  function settings() {
    var h = []; for (var w = 0; w < clip.children.length; w++) find(clip.children[w], "clipFilterHeading", h)
    console.log("QUE filter heading '" + h[0].text + "' w=" + h[0].width + " implicit=" + h[0].implicitWidth + (h[0].implicitWidth <= h[0].width ? " fits" : " CUT"))
    var pills = []; for (var w2 = 0; w2 < clip.children.length; w2++) find(clip.children[w2], "clipClickPill", pills)
    console.log("QUE click pills " + pills.map(function(p) { return "'" + p.text + "'" + (p.active ? "(active)" : "") }).join(" "))
    var texts = []
    var all = 0
    function walk(it) { if (!it) return; if (it.text !== undefined) all++; if (it.text !== undefined && /(type:|app:|is:p|today|yesterday|30m|Images)/.test(String(it.text))) texts.push(it); var k = it.children || []; for (var i = 0; i < k.length; i++) walk(k[i]); if (it.contentItem && it.contentItem !== it) walk(it.contentItem) }
    for (var w3 = 0; w3 < clip.children.length; w3++) walk(clip.children[w3])
    console.log("QUE texts seen " + all)
    console.log("QUE filter rows " + texts.map(function(x) { return x.text + (x.implicitWidth <= x.width + 0.5 ? "" : "(CUT)") }).join(" | "))
    t5.start()
  }
}
