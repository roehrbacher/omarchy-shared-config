import Quickshell
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Ui
// 1.19.0 on the real Clipboard.qml (stub helpers): auto queue on close,
// info line, single pick, running-queue badges, on-clipboard mark, QR + OCR
// buttons, lock icon, Markdown + plain text, unpin to the top of History.
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
  function all(name) { var o = []; for (var w = 0; w < clip.children.length; w++) find(clip.children[w], name, o); return o }
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
  Timer { id: t3; interval: 700; onTriggered: shell.check2() }
  Timer { id: t4; interval: 700; onTriggered: shell.check3() }
  Timer { id: t5; interval: 900; onTriggered: shell.settings() }
  function run() {
    var now = Date.now()
    clip.history = [
      { type: "text", text: "pin A", pinned: true, at: now },
      { type: "text", text: "pin old", pinned: true, at: now - 9 * 86400000 },
      { type: "image", path: "/nonexistent/" + "b".repeat(64) + ".png", mime: "image/png", bytes: 900, at: now, screenshot: true, qr: "WIFI:T:WPA;S:ExampleNet;P:not-a-real-pass;;", ocr: "Guest network", scanned: true, scanv: 2 },
      { type: "text", text: "Docs", html: "<h2>Docs</h2>", at: now },
      { type: "text", text: "alpha", at: now - 1000 },
      { type: "text", text: "beta", at: now - 2000 }
    ]
    clip.rebuildDisplay(false)
    clip.cursorActive = true
    t2.start()
  }
  function rowsNow() { var l = all("resultList"); var r = []; find(l[0], "clipRow", r); return r.sort(function(a, b) { return a.index - b.index }) }
  function acts(row) { var a = []; find(row, "clipAction", a); return a.filter(function(x) { return x.visible && x.parent.visible }).map(function(x) { return x.tooltipText + "[" + (String(x.iconText).codePointAt(0) || 0).toString(16) + "]" }).join(",") }
  function footer() { var b = all("clipQueueButton"); return b.length && b[0].visible ? b[0].label + (b[0].info ? " (info)" : " (button)") : "(hidden)" }
  function order() { var o = []; for (var i = 0; i < clip.displayModelCount(); i++) { var r = clip.displayModelGet(i); o.push((clip.history[r.historyIndex].text || "img") + (r.pinned ? "*" : "")) } return o.join(" ") }
  function check() {
    var rows = rowsNow()
    clip.selectedIndex = 2; console.log("QUE QR+OCR row '" + rows[2].previewText + "' actions=" + acts(rows[2]))
    clip.selectedIndex = 3; console.log("QUE html row actions=" + acts(rows[3]))
    // on-clipboard mark: "alpha" is on the clipboard
    clip.currentClipKey = "text:" + Qt.md5("alpha")
    var marks = all("clipCurrentMark").filter(function(m) { return m.visible })
    console.log("QUE marked rows: " + marks.map(function(m) { return m.parent.previewText }).join(","))
    clip.currentClipKey = "image:" + "b".repeat(64)
    marks = all("clipCurrentMark").filter(function(m) { return m.visible })
    console.log("QUE marked after live change: " + marks.map(function(m) { return m.parent.previewText }).join(","))
    // single Ctrl-selected row: plain pick, no queue
    clip.toggleQueueIndex(4)
    console.log("QUE 1 selected footer=" + footer())
    clip.close()
    console.log("QUE closed with 1 selected: keys=" + clip.queueKeys.length)
    clip.open("{}"); t3.start()
  }
  function check2() {
    clip.toggleQueueIndex(5); clip.toggleQueueIndex(4)
    console.log("QUE 2 selected footer=" + footer())
    clip.handleSearchKey({ key: Qt.Key_Escape, modifiers: 0, accepted: false, text: "" })
    console.log("QUE Esc: keys=" + clip.queueKeys.length + " opened=" + clip.opened)
    clip.toggleQueueIndex(5); clip.toggleQueueIndex(4)
    clip.activateIndex(0)   // click / Enter with 2+ selected = close + queue
    console.log("QUE after click with 2 selected: opened=" + clip.opened)
    clip.open("{}")
    t4.start()
  }
  function check3() {
    clip.applyQueueFile(JSON.stringify({ items: [{ type: "text", text: "beta" }, { type: "text", text: "alpha" }], pos: 1 }))
    var b = rowsNow().map(function(r) { var x = []; find(r, "clipQueueBadge", x); return r.previewText + "=" + (x[0].visible ? r.queueNo + (r.queueInfo.done ? "(done)" : "") : "-") })
    console.log("QUE reopened during queue: footer=" + footer() + " badges " + b.join(" "))
    clip.applyQueueFile("")
    // unpin by drag: "pin old" (index 1) into History -> top of History
    clip.dragStart(1); for (var d = 2; d <= 4; d++) clip.dragMoveTo(d); clip.dragFinish()
    console.log("QUE after unpin drag: " + order())
    clip.infoOpen = true; t5.start()
  }
  function settings() {
    var h = all("clipOcrHeading"), c = all("clipOcrCmd")
    console.log("QUE ocr heading '" + h[0].text + "' fits=" + (h[0].implicitWidth <= h[0].width) + " cmd='" + c[0].text + "' installed=" + clip.ocrInfo.installed.join(",") + " used=" + clip.ocrInfo.used)
    Qt.quit()
  }
}
