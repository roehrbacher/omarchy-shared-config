// Run: QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests/tst_dragflicker.qml
// Dragging a pinned row (same move/hasCursor logic as Clipboard.qml 1.15.1):
// no other row may get the highlight for even one binding step (that started
// the stock 60 ms colour fade on the passed rows = the flicker), Alt+N slots
// follow the order live, and the drop leaves the delegates in place.
import QtQuick
import QtTest

Item {
  id: root
  width: 300; height: 400
  property bool identity: true        // 1.15.1 logic; false = 1.15.0
  property int selectedIndex: 0
  property int dragRow: -1
  property int dragHistoryIndex: -1
  property var flashes: []            // historyIndex of rows that gained the cursor during a drag
  ListModel { id: displayModel }

  function fill() {
    displayModel.clear()
    for (var i = 0; i < 5; i++) displayModel.append({ historyIndex: i, pinned: true, slot: i + 1 })
    for (var j = 5; j < 10; j++) displayModel.append({ historyIndex: j, pinned: false, slot: j + 1 })
  }
  function dragMoveTo(target) {
    target = Math.max(0, Math.min(4, target))
    if (target === dragRow) return
    displayModel.move(dragRow, target, 1)
    dragRow = target
    selectedIndex = target
    if (identity) for (var i = 0; i <= 4; i++) if (displayModel.get(i).slot !== i + 1) displayModel.setProperty(i, "slot", i + 1)
  }

  ListView {
    id: list
    anchors.fill: parent
    model: displayModel
    delegate: Rectangle {
      required property int index
      required property int historyIndex
      required property int slot
      readonly property bool hasCursor: root.identity && root.dragRow >= 0 && root.dragHistoryIndex >= 0
        ? historyIndex === root.dragHistoryIndex : index === root.selectedIndex
      onHasCursorChanged: if (hasCursor && root.dragRow >= 0 && historyIndex !== root.dragHistoryIndex) root.flashes.push(historyIndex)
      width: 300; height: 30
      color: hasCursor ? "#444" : "transparent"
      Behavior on color { ColorAnimation { duration: 60 } }
    }
  }

  TestCase {
    name: "DragFlicker"
    when: windowShown
    function drag(useIdentity) {
      root.identity = useIdentity; root.flashes = []; fill(); wait(20)
      root.selectedIndex = 0; root.dragRow = 0; root.dragHistoryIndex = 0
      var first = list.itemAtIndex(0)
      for (var t = 1; t <= 4; t++) { dragMoveTo(t); wait(5) }
      for (var b = 3; b >= 2; b--) { dragMoveTo(b); wait(5) }
      root.dragRow = -1; root.dragHistoryIndex = -1
      return first
    }
    function test_oldLogicFlashes() {
      drag(false)
      verify(root.flashes.length > 0, "1.15.0 logic lights up passed rows: " + root.flashes)
    }
    function test_noFlashAndLiveSlots() {
      var first = drag(true)
      compare(root.flashes.length, 0, "no passed row gets the highlight")
      compare(displayModel.get(2).historyIndex, 0, "dragged entry ends at row 2")
      for (var i = 0; i < 5; i++) compare(displayModel.get(i).slot, i + 1, "slot " + i)
      verify(list.itemAtIndex(2) === first, "same delegate kept (no rebuild)")
      verify(list.itemAtIndex(2).hasCursor, "cursor stays on the dropped row")
    }
  }
}
