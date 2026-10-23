import Quickshell
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Ui
// 1.16.0: image rows with OCR / QR text get the right buttons; filters work.
ShellRoot {
  id: shell
  property var clip: null
  function find(item, name, out) {
    if (!item) return
    if (item.objectName === name) out.push(item)
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) find(kids[i], name, out)
    if (item.contentItem && item.contentItem !== item) find(item.contentItem, name, out)
  }
  Window { id: win; width: 700; height: 900; visible: true }
  Component.onCompleted: {
    var c = Qt.createComponent("clip/Clipboard.qml")
    if (c.status !== Component.Ready) { console.log("IMG ERR " + c.errorString()); Qt.quit(); return }
    clip = c.createObject(win.contentItem, {})
    clip.open("{}")
    t.start()
  }
  Timer { id: t; interval: 3000; onTriggered: shell.run() }
  Timer { id: t2; interval: 800; onTriggered: shell.check() }
  function run() {
    var now = Date.now()
    clip.history = [
      { type: "image", path: "/nonexistent/o.png", mime: "image/png", bytes: 1000, screenshot: true, at: now, ocr: "Invoice 4711", scanned: true },
      { type: "image", path: "/nonexistent/q.png", mime: "image/png", bytes: 1000, at: now, qr: "https://example.com/menu", scanned: true },
      { type: "image", path: "/nonexistent/w.png", mime: "image/png", bytes: 1000, at: now, qr: "WIFI:T:WPA;S:Test;P:hunter2;;", scanned: true },
      { type: "text", text: "hello", at: now, app: "kitty", pinned: true },
      { type: "text", text: "https://example.org", at: now - 3 * 3600000 }
    ]
    clip.rebuildDisplay(false)
    clip.cursorActive = true
    t2.start()
  }
  function rowsNow() {
    var list = []; for (var w = 0; w < clip.children.length; w++) find(clip.children[w], "resultList", list)
    var rows = []; find(list[0], "clipRow", rows); return rows
  }
  function check() {
    var rows = rowsNow().sort(function(a, b) { return a.index - b.index })
    for (var i = 0; i < rows.length; i++) {
      clip.selectedIndex = rows[i].index
      var acts = []; find(rows[i], "clipAction", acts)
      console.log("IMG row " + rows[i].previewText + " link=" + rows[i].linkKind + " actions=[" + acts.filter(function(x) { return x.visible && x.parent.visible }).map(function(x) { return x.tooltipText }).join(",") + "] keys=" + clip.selectedActions.join(","))
    }
    var q = ["type:image", "invoice", "menu", "app:kitty", "is:pinned", "<2h", "type:link today", "type:screenshot"]
    for (var k = 0; k < q.length; k++) { clip.setFilter(q[k]); console.log("IMG filter '" + q[k] + "' -> " + clip.displayModelCount()) }
    clip.setFilter(""); clip.infoOpen = true; t3.start()
  }
  Timer { id: t3; interval: 800; onTriggered: shell.info() }
  function texts(item, out) { if (!item) return; if (item.text !== undefined && String(item.text).indexOf("is:pinned") >= 0) out.push(item); var k = item.children || []; for (var i = 0; i < k.length; i++) texts(k[i], out); if (item.contentItem && item.contentItem !== item) texts(item.contentItem, out) }
  function info() {
    var o = []; for (var w = 0; w < clip.children.length; w++) texts(clip.children[w], o)
    console.log("IMG info " + o.map(function(x) { return "'" + x.text + "' w=" + x.width + " implicit=" + x.implicitWidth + (x.truncated ? " TRUNCATED" : " fits") }).join(" | "))
    Qt.quit()
  }
}
