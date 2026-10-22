// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_keepscroll.qml
// Pinning a row far down the list must not move the viewport: the same
// anchor logic as Clipboard.qml (rebuildDisplay(true, moved) + restoreAnchor),
// on a ListView with Pinned / History sections and 40 rows.
import QtQuick
import QtTest
import "../ClipboardHistory.js" as H

Item {
  id: root
  width: 300; height: 300
  property var history: []
  ListModel { id: displayModel }

  function rowKey(r) { return r ? r.entryType + "\n" + r.path + "\n" + r.fullText : "" }
  function rebuild(keepScroll, moved) {
    var anchors = []
    if (keepScroll) {
      var top = list.indexAt(10, list.contentY + 1)
      for (var a = Math.max(0, top); a >= 0 && a < displayModel.count && anchors.length < 4; a++) {
        var ar = displayModel.get(a)
        if (ar.historyIndex === moved) continue
        var it = list.itemAtIndex(a)
        if (it) anchors.push({ key: rowKey(ar), pinned: ar.pinned, offset: it.y - list.contentY })
      }
    }
    var rows = H.displayRows(root.history, "", 200)
    var pc = 0; for (var p = 0; p < rows.length; p++) if (rows[p].pinned) pc++
    displayModel.clear()
    for (var i = 0; i < rows.length; i++) displayModel.append({ entryType: rows[i].entryType, path: rows[i].path, fullText: rows[i].fullText,
      pinned: rows[i].pinned, historyIndex: rows[i].index, sectionName: H.sectionName(rows[i].pinned, pc, false, rows.length) })
    if (keepScroll) restoreAnchor(anchors)
  }
  function restoreAnchor(anchors) {
    for (var k = 0; k < anchors.length; k++) for (var j = 0; j < displayModel.count; j++) {
      var r = displayModel.get(j)
      if (r.pinned !== anchors[k].pinned || rowKey(r) !== anchors[k].key) continue
      list.positionViewAtIndex(j, ListView.Beginning)
      var it = list.itemAtIndex(j); if (!it) return false
      var maxY = list.originY + Math.max(0, list.contentHeight - list.height)
      list.contentY = Math.max(list.originY, Math.min(maxY, it.y - anchors[k].offset)); return true
    }
    return false
  }

  ListView {
    id: list
    anchors.fill: parent
    model: displayModel
    section.property: "sectionName"
    section.delegate: Item { required property string section; width: 300; height: section ? 20 : 0 }
    delegate: Rectangle { required property string fullText; width: 300; height: 30 }
  }

  TestCase {
    name: "KeepScroll"
    when: windowShown
    function firstVisibleText() { return displayModel.get(list.indexAt(10, list.contentY + 1)).fullText }
    function test_pinKeepsViewport() {
      var h = []; for (var i = 0; i < 40; i++) h.push({ type: "text", text: "item " + i })
      h[0].pinned = true; h[1].pinned = true
      root.history = h; rebuild(false)
      list.positionViewAtIndex(20, ListView.Beginning)
      wait(50)
      var before = firstVisibleText()
      var moved = 25
      root.history = H.togglePinAt(root.history, moved)   // pin "item 25" (moves to the top)
      rebuild(true, moved)
      wait(50)
      compare(firstVisibleText(), before, "same row at the top after pinning")
      root.history = H.togglePinAt(root.history, moved)   // and unpin it again
      rebuild(true, moved)
      wait(50)
      compare(firstVisibleText(), before, "same row at the top after unpinning")
    }
    function test_deleteKeepsViewport() {
      var h = []; for (var i = 0; i < 40; i++) h.push({ type: "text", text: "row " + i })
      h[0].pinned = true
      root.history = h; rebuild(false); wait(50)
      list.positionViewAtIndex(15, ListView.Beginning); wait(50)
      var before = firstVisibleText()
      root.history = H.removeEntryAt(root.history, 30)
      rebuild(true, -1); wait(50)
      compare(firstVisibleText(), before)
    }
  }
}
