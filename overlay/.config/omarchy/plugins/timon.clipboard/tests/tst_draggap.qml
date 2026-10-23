// Run: QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests/tst_draggap.qml
// 1.16.0: dragging a pinned row across the spacing between rows must not
// send it to the top/bottom for a frame (1.15.1: indexAt() = -1 in the gap
// -> clamp to first/last = the remaining flicker). Same target logic as
// Clipboard.qml; `fixed: false` replays the 1.15.1 logic.
import QtQuick
import QtTest

Item {
  id: root
  width: 300; height: 600
  property bool fixed: true
  property int dragRow: -1
  property var positions: []
  ListModel { id: m }
  ListView {
    id: list
    anchors.fill: parent
    model: m
    spacing: 4
    delegate: Rectangle { required property int index; required property int hid; width: 300; height: 30 }
  }
  function targetFor(y) {
    var t = list.indexAt(10, y)
    if (t < 0) {
      if (fixed && list.indexAt(10, y - list.spacing - 1) >= 0) return -2
      var rowY = list.itemAtIndex(dragRow).y
      t = y < rowY ? 0 : 4
    }
    return Math.max(0, Math.min(4, t))
  }
  function sweep() {
    m.clear(); for (var i = 0; i < 8; i++) m.append({ hid: i }); list.forceLayout()
    dragRow = 0; positions = []
    for (var y = 15; y <= 4 * 34 + 15; y++) {
      var t = targetFor(y)
      if (t === -2 || t === dragRow) continue
      m.move(dragRow, t, 1); list.forceLayout(); dragRow = t; positions.push(t)
    }
    return positions
  }
  TestCase {
    name: "DragGap"; when: windowShown
    function test_old_jumps() { root.fixed = false; var p = root.sweep(); verify(p.indexOf(4) < p.length - 1, "1.15.1 jumps to the end in a gap: " + p) }
    function test_new_steps() {
      root.fixed = true; var p = root.sweep()
      for (var i = 0; i < p.length; i++) compare(p[i], i + 1, "one step at a time: " + p)
      compare(p[p.length - 1], 4)
    }
  }
}
