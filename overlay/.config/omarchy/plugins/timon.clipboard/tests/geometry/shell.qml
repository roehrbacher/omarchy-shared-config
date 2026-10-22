import Quickshell
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Ui
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
  function g(it, ref) { var p = it.mapToItem(ref, 0, 0); return "x=" + p.x + " y=" + p.y + " w=" + it.width + " h=" + it.height }
  Component.onCompleted: {
    var c = Qt.createComponent("clip/Clipboard.qml")
    if (c.status !== Component.Ready) { console.log("GEO ERR " + c.errorString()); return }
    clip = c.createObject(win.contentItem, {})
    clip.open("{}")
    t.start()
  }
  Window { id: win; width: 700; height: 900; visible: true }
  Timer { id: later; property var cb; interval: 2500; onTriggered: cb() }
  Timer { id: t; interval: 4000; onTriggered: shell.measure() }
  function measure() {
    clip.history = [
      { type: "text", text: "pinned one", pinned: true },
      // 1.14.0 day headings: today, yesterday, 3 days ago, no time
      { type: "text", text: "today item", at: Date.now() },
      { type: "text", text: "yesterday item", at: Date.now() - 86400000 },
      { type: "text", text: "older item", at: Date.now() - 3 * 86400000 },
      { type: "text", text: "https://example.com" },
      { type: "text", text: "#ff8800" },
      { type: "text", text: "+43 664 1234567" },
      { type: "text", text: "/etc" },
      { type: "text", text: "/nonexistent/x" },
      { type: "text", text: "Neubaugasse 12, 1070 Wien" },
      { type: "text", text: "roehrbacher/omarchy-clipboard#3" },
      { type: "text", text: "plain" },
      { type: "image", path: "/nonexistent/a.png", mime: "image/png", capturedAt: "Thursday 20:40", bytes: 250880, screenshot: true }
    ]
    clip.rebuildDisplay(false)
    clip.cursorActive = true; clip.selectedIndex = 1
    Qt.callLater(function() {
      var ref = null, l = []
      var all = []
      // search from every window
      var wins = []
      wins = clip.children.slice ? clip.children.slice() : []; for (var k = 0; k < clip.children.length; k++) wins.push(clip.children[k]); console.log("GEO kids " + clip.children.length)
      var title = [], btn = [], list = [], rows = [], texts = [], acts = []
      for (var w = 0; w < wins.length; w++) {
        find(wins[w], "headerTitle", title); find(wins[w], "searchButton", btn); find(wins[w], "resultList", list)
      }
      if (!list.length) { console.log("GEO nolist"); Qt.quit(); return }
      find(list[0], "clipRow", rows); find(list[0], "clipRowText", texts); 
      ref = list[0]
      console.log("GEO model=" + clip.children.length + " rows=" + rows.length)
      for (var r = 0; r < Math.min(rows.length, 2); r++) console.log("GEO row " + g(rows[r], ref) + " text " + g(texts[r], ref))
      console.log("GEO title " + g(title[0], ref) + " searchBtn " + g(btn[0], ref) + " list w=" + ref.width)
      var dm = []
      for (var i = 0; i < rows.length; i++) { var acts = []; find(rows[i], "clipAction", acts); var v = acts.filter(function(x){return x.visible}).map(function(x){return x.tooltipText + "@" + x.mapToItem(ref,0,0).x + "+" + x.width}); dm.push(rows[i].previewText + "=" + rows[i].linkKind + "[" + v.join(",") + "]") }
      console.log("GEO kinds " + dm.join(" | "))
      // incremental update: remove one row, delegates must be reused
      var before = rows.slice()
      clip.history = clip.history.filter(function(e) { return e.text !== "plain" })
      clip.rebuildDisplay(true, -1)
      later.cb = function() {
        var after = []; find(list[0], "clipRow", after)
        var kept = 0; for (var a = 0; a < after.length; a++) if (before.indexOf(after[a]) >= 0) kept++
        console.log("GEO incremental kept=" + kept + "/" + after.length)
        var d = []; for (var q = 0; q < after.length; q++) d.push(after[q].previewText + "=" + after[q].linkKind)
        console.log("GEO after " + d.join(" | "))
        var acts = []; find(after[1], "clipAction", acts)
      // 1.13.1: on a non-highlighted colour row the swatch sits left of Alt+N.
      for (var c = 0; c < after.length; c++) {
        var sw = [], hint = []; find(after[c], "clipSwatch", sw); find(after[c], "clipSlotHint", hint)
        sw = sw.filter(function(x){return x.visible}); hint = hint.filter(function(x){return x.visible && x.parent.visible})
        if (sw.length && hint.length) {
          var sx = sw[0].mapToItem(ref,0,0).x, hx = hint[0].mapToItem(ref,0,0).x
          console.log("GEO swatch row=" + c + " swatch x=" + sx + "+" + sw[0].width + " altN x=" + hx + " " + (sx + sw[0].width <= hx ? "LEFT-OK" : "WRONG"))
        }
        if (after[c].entryType === "image") console.log("GEO image text=" + after[c].previewText)
      }
        var hs = []; find(list[0], "clipSectionHeading", hs)
        hs = hs.filter(function(x){return x.visible}).sort(function(a,b){return a.mapToItem(ref,0,0).y - b.mapToItem(ref,0,0).y})
        console.log("GEO headings " + hs.map(function(x){var p=x.mapToItem(ref,0,0);return x.text+"@x="+p.x+",y="+p.y+",h="+x.height+",px="+x.font.pixelSize}).join(" | "))
        var seps = []; find(list[0], "clipSep", seps)
        console.log("GEO separators visible=" + seps.filter(function(x){return x.visible}).length)
        console.log("GEO row1 actions " + acts.filter(function(x){return x.visible}).map(function(x){var p=x.mapToItem(ref,0,0);return x.tooltipText+"@x="+p.x+",w="+x.width+",right="+(p.x+x.width)}).join(" "))
      }
      later.start()
    })
  }
}
