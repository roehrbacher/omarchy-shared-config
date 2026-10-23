import Quickshell
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Ui
// 1.17.0: Markdown button on rows with formatted HTML; paste queue badges,
// footer button, Ctrl+Space / Ctrl+Enter / Esc and the items queue.sh gets
// (queue.sh is a stub in this run: it only records its stdin).
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
    if (c.status !== Component.Ready) { console.log("QUE ERR " + c.errorString()); Qt.quit(); return }
    clip = c.createObject(win.contentItem, {})
    clip.open("{}")
    t.start()
  }
  Timer { id: t; interval: 3000; onTriggered: shell.run() }
  Timer { id: t2; interval: 600; onTriggered: shell.check() }
  Timer { id: t3; interval: 600; onTriggered: shell.check2() }
  Timer { id: t4; interval: 1500; onTriggered: { console.log("QUE opened after start=" + clip.opened + " keys=" + clip.queueKeys.length); Qt.quit() } }
  function run() {
    var now = Date.now()
    clip.history = [
      { type: "text", text: "Docs heading link", html: "<h2>Docs</h2><p><a href='https://e.x'>link</a></p>", at: now },
      { type: "text", text: "alpha", at: now - 1000 },
      { type: "text", text: "beta", at: now - 2000 },
      { type: "text", text: "gamma", at: now - 3000 }
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
  function badges() {
    return rowsNow().map(function(r) { var b = []; find(r, "clipQueueBadge", b); return r.previewText + "=" + (b.length && b[0].visible ? r.queueNo : "-") }).join(" ")
  }
  function footer() { var b = []; for (var w = 0; w < clip.children.length; w++) find(clip.children[w], "clipQueueButton", b); return b.length && b[0].visible ? b[0].label : "(hidden)" }
  function key(k, mods) { var ev = { key: k, modifiers: mods || 0, accepted: false, text: "" }; clip.handleSearchKey(ev); return ev.accepted }
  function check() {
    var rows = rowsNow()
    clip.selectedIndex = 0
    console.log("QUE row0 actions=[" + acts(rows[0]) + "] keys=" + clip.selectedActions.join(","))
    clip.selectedIndex = 1
    console.log("QUE row1 actions=[" + acts(rows[1]) + "] keys=" + clip.selectedActions.join(","))
    console.log("QUE footer before=" + footer())
    // Ctrl+click order: gamma, alpha, beta (the click handler calls toggleQueueIndex)
    clip.toggleQueueIndex(3); clip.toggleQueueIndex(1); clip.toggleQueueIndex(2)
    console.log("QUE badges " + badges() + " footer=" + footer())
    clip.toggleQueueIndex(1)
    console.log("QUE after un-ctrl-click alpha: " + badges())
    clip.selectedIndex = 1
    key(Qt.Key_Space, Qt.ControlModifier)
    console.log("QUE after Ctrl+Space on alpha: " + badges())
    key(Qt.Key_Escape, 0)
    console.log("QUE after Esc: " + badges() + " opened=" + clip.opened + " footer=" + footer())
    clip.toggleQueueIndex(2); clip.toggleQueueIndex(3)
    clip.queueRunning = null
    t3.start()
  }
  function check2() {
    console.log("QUE before close: " + badges())
    clip.close()  // 1.19.0: closing with 2+ selected starts the queue
    clip.queueRunning = { pos: 1, count: 5 }
    console.log("QUE running footer=" + footer())
    t4.start()
  }
}
