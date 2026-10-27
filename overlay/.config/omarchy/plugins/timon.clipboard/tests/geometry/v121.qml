import Quickshell
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Ui
// 1.21.0 on the real Clipboard.qml (stub helpers, queue.sh, notifier and
// wl-copy): accent pill behind the queue info line; a pick or row action
// while a queue is armed drops it quietly; OCR copy notification uses the
// copy glyph; no incognito notifications; short OCR help text.
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
  function texts(item, out) { if (!item) return; if (item.text !== undefined && item.truncated !== undefined) out.push(item); var k = item.children || []; for (var i = 0; i < k.length; i++) texts(k[i], out) }
  function all(name) { var o = []; for (var w = 0; w < clip.children.length; w++) find(clip.children[w], name, o); return o }
  Window { id: win; width: 700; height: 900; visible: true }
  Component.onCompleted: {
    var c = Qt.createComponent("clip/Clipboard.qml")
    if (c.status !== Component.Ready) { console.log("V121 ERR " + c.errorString()); Qt.quit(); return }
    clip = c.createObject(win.contentItem, {})
    clip.open("{}")
    t.start()
  }
  Timer { id: t; interval: 3000; onTriggered: shell.step1() }
  Timer { id: t2; interval: 1500; onTriggered: shell.step2() }
  Timer { id: t3; interval: 1500; onTriggered: shell.step3() }
  Timer { id: t4; interval: 1500; onTriggered: { console.log("V121 done"); Qt.quit() } }
  function step1() {
    var now = Date.now()
    clip.history = [
      { type: "text", text: "newest", at: now },
      { type: "text", text: "pin A", pinned: true, at: now - 10 },
      { type: "image", path: "/nonexistent/" + "b".repeat(64) + ".png", mime: "image/png", bytes: 900, at: now, screenshot: true, qr: "WIFI:T:WPA;S:ExampleNet;P:not-a-real-pass;;", ocr: "Guest network", scanned: true, scanv: 3 },
      { type: "text", text: "alpha", at: now - 1000 },
      { type: "text", text: "beta", at: now - 2000 }
    ]
    clip.rebuildDisplay(false)
    clip.toggleQueueIndex(3); clip.toggleQueueIndex(4); clip.toggleQueueIndex(0)
    t2.start()
  }
  function step2() {
    var b = all("clipQueueButton")[0], tx = []; texts(b, tx)
    var badge = all("clipQueueBadge").filter(function(x) { return x.visible })[0]
    var circle = badge ? badge.children[0] : null
    console.log("V121 info line '" + b.label + "' pill=" + (String(b.color) === String(circle.color)) + " (pill " + b.color + ", circles " + circle.color + ") round=" + (b.radius === b.height / 2)
      + " height " + b.height + " text colour = circle number colour: " + (String(tx[0].color) === String(circle.children[0].color)) + " truncated=" + tx[0].truncated)
    // An armed queue from before, then the OCR button on a screenshot row.
    clip.queueKeys = []
    clip.queueRunning = { pos: 1, count: 4 }
    var wifi = -1; for (var i = 0; i < clip.displayModelCount(); i++) if (clip.displayModelGet(i).copyWifi) wifi = i
    clip.copyOcrText(wifi)
    console.log("V121 OCR copy while queue armed: queueRunning=" + JSON.stringify(clip.queueRunning))
    // Armed again, popup open, plain pick (Enter) on a row.
    clip.open("{}")
    clip.queueRunning = { pos: 0, count: 2 }
    clip.activateIndex(0)
    console.log("V121 plain pick while queue armed: queueRunning=" + JSON.stringify(clip.queueRunning) + " opened=" + clip.opened)
    // Armed + 2 rows selected, then a row action (QR copy): no new queue either.
    clip.open("{}")
    clip.queueRunning = { pos: 0, count: 2 }
    clip.toggleQueueIndex(3); clip.toggleQueueIndex(4)
    clip.copyImageText(wifi)
    console.log("V121 QR copy with 2 rows selected: queueKeys=" + clip.queueKeys.length + " queueRunning=" + JSON.stringify(clip.queueRunning))
    clip.setPrivate(true, true); clip.setPrivate(false, true)
    clip.open("{}"); clip.openInfo()
    t3.start()
  }
  function step3() {
    var help = all("clipOcrHelp")[0]
    console.log("V121 help (" + help.lineCount + " lines): " + help.text.replace(/\n/g, " | "))
    t4.start()
  }
}
