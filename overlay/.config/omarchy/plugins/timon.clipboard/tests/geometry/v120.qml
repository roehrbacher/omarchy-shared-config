import Quickshell
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Ui
// 1.20.0 on the real Clipboard.qml (stub helpers, stub notifier, stub
// wl-copy): empty clipboard -> top pinned item copied on open; short queue
// info line fits; notifications with glyph + body; OCR language settings.
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
    if (c.status !== Component.Ready) { console.log("V120 ERR " + c.errorString()); Qt.quit(); return }
    clip = c.createObject(win.contentItem, {})
    clip.open("{}")
    t.start()
  }
  Timer { id: t; interval: 3000; onTriggered: shell.step1() }
  Timer { id: t2; interval: 1500; onTriggered: shell.step2() }
  Timer { id: t3; interval: 1500; onTriggered: shell.step3() }
  Timer { id: t4; interval: 1500; onTriggered: { console.log("V120 done"); Qt.quit() } }
  function step1() {
    var now = Date.now()
    clip.history = [
      { type: "text", text: "newest", at: now },
      { type: "text", text: "pin A", pinned: true, at: now - 10 },
      { type: "text", text: "pin B", pinned: true, at: now - 20 },
      { type: "image", path: "/nonexistent/" + "b".repeat(64) + ".png", mime: "image/png", bytes: 900, at: now, screenshot: true, qr: "WIFI:T:WPA;S:ExampleNet;P:not-a-real-pass;;", ocr: "Guest network", scanned: true, scanv: 3 },
      { type: "text", text: "alpha", at: now - 1000 },
      { type: "text", text: "beta", at: now - 2000 }
    ]
    clip.rebuildDisplay(false)
    clip.close()
    clip.open("{}")        // stub `clipboard.sh current` says "empty"
    t2.start()
  }
  function step2() {
    var marks = all("clipCurrentMark").filter(function(m) { return m.visible })
    console.log("V120 after open on empty clipboard: currentClipKey=" + (clip.currentClipKey === "text:" + Qt.md5("pin A") ? "pin A" : clip.currentClipKey) + " marked=" + marks.map(function(m) { return m.parent.previewText }).join(",") + " opened=" + clip.opened)
    clip.toggleQueueIndex(4); clip.toggleQueueIndex(5); clip.toggleQueueIndex(0)
    var b = all("clipQueueButton")[0], tx = []; texts(b, tx)
    console.log("V120 queue info line '" + b.label + "' truncated=" + tx.map(function(x) { return x.truncated }).join(",") + " width " + Math.round(tx[0].implicitWidth) + "/" + Math.round(tx[0].width))
    clip.handleSearchKey({ key: Qt.Key_Escape, modifiers: 0, accepted: false, text: "" })
    // Wi-Fi row: copy password -> notification (stub)
    var wifi = -1; for (var i = 0; i < clip.displayModelCount(); i++) if (clip.displayModelGet(i).copyWifi) wifi = i
    clip.copyImageText(wifi)
    clip.copyOcrText(wifi)
    clip.setPrivate(true, true); clip.setPrivate(false, true)
    clip.open("{}"); clip.openInfo()
    t3.start()
  }
  function step3() {
    var h = all("clipOcrHeading")[0], help = all("clipOcrHelp")[0], rows = all("clipOcrLang")
    console.log("V120 heading '" + h.text + "' fits=" + (h.implicitWidth <= h.width))
    console.log("V120 help (" + help.lineCount + " lines): " + help.text.replace(/\n/g, " | "))
    console.log("V120 language rows " + rows.length + ": " + rows.map(function(r) { return r.modelData.name + "=" + (r.installed ? "Installed" : r.cmd.replace("sudo pacman -S tesseract-data-", "")) }).join(", "))
    var fr = rows.filter(function(r) { return r.code === "fra" })[0]
    clip.copyOcrInstall(fr.modelData)
    var en = rows.filter(function(r) { return r.code === "eng" })[0]
    clip.copyOcrInstall(en.modelData)   // installed: must do nothing
    t4.start()
  }
}
