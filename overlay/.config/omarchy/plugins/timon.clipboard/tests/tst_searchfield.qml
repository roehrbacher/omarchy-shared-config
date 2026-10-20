// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_searchfield.qml
// Offscreen, so it never touches the desktop or the real clipboard. A text
// field set up like the popup's search line, with the same key routing
// (ClipboardHistory.searchKeyAction); "copied" stands in for wl-copy.
import QtQuick
import QtTest
import "../ClipboardHistory.js" as ClipboardHistory

Item {
  id: root
  width: 400
  height: 60
  property var actions: []
  property var copied: []
  property string pendingSlot: ""
  property bool rowPinned: false
  property bool armed: false

  TextInput {
    id: field
    anchors.fill: parent
    focus: true
    selectByMouse: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      var action = ClipboardHistory.searchKeyAction({
        key: event.key,
        ctrl: (event.modifiers & Qt.ControlModifier) !== 0,
        alt: (event.modifiers & Qt.AltModifier) !== 0,
        shift: (event.modifiers & Qt.ShiftModifier) !== 0,
        hasSelection: field.selectedText.length > 0
      })
      if (action === "") return
      if (action === "copySelection") root.copied = root.copied.concat([field.selectedText])
      else if (action === "cutSelection") {
        root.copied = root.copied.concat([field.selectedText])
        field.remove(field.selectionStart, field.selectionEnd)
      } else if (action === "clearSearch") field.text = ""
      else {
        if (action !== "delete") root.armed = false
        if (action === "slot") root.pendingSlot = action
        if (action === "delete") {
          // Same rule as Clipboard.qml requestDelete()
          if (ClipboardHistory.deleteAction(root.rowPinned, root.armed) === "arm") action = "arm"
          root.armed = action === "arm"
        }
        root.actions = root.actions.concat([action])
      }
      event.accepted = true
    }
    Keys.onReleased: function(event) {
      if (root.pendingSlot !== "" && ClipboardHistory.isModifierKey(event.key)) {
        root.actions = root.actions.concat(["paste:" + root.pendingSlot])
        root.pendingSlot = ""
        event.accepted = true
      }
    }
  }

  TestCase {
    name: "SearchField"
    when: windowShown

    function init() {
      field.text = ""
      root.actions = []
      root.copied = []
      root.pendingSlot = ""
      root.rowPinned = false
      root.armed = false
      field.forceActiveFocus()
    }

    function type(s) { for (var i = 0; i < s.length; i++) keyClick(s[i]) }

    function test_ctrlA_ctrlC_copies_search_text() {
      type("not found")
      compare(field.text, "not found")
      keyClick(Qt.Key_A, Qt.ControlModifier)
      compare(field.selectedText, "not found")
      keyClick(Qt.Key_C, Qt.ControlModifier)
      compare(root.copied, ["not found"])
      compare(field.text, "not found", "copy leaves the search alone")
      compare(root.actions, [])
    }

    function test_ctrlX_cuts() {
      type("abc")
      keyClick(Qt.Key_A, Qt.ControlModifier)
      keyClick(Qt.Key_X, Qt.ControlModifier)
      compare(root.copied, ["abc"])
      compare(field.text, "")
    }

    function test_ctrlC_without_selection_copies_nothing() {
      type("abc")
      keyClick(Qt.Key_C, Qt.ControlModifier)
      compare(root.copied, [])
    }

    function test_shift_arrows_select() {
      type("hello")
      keyClick(Qt.Key_Left, Qt.ShiftModifier)
      keyClick(Qt.Key_Left, Qt.ShiftModifier)
      compare(field.selectedText, "lo")
      keyClick(Qt.Key_Home, Qt.ShiftModifier)
      compare(field.selectedText, "hello")
      compare(root.actions, [], "no list movement")
    }

    function test_ctrl_backspace_deletes_word() {
      type("foo bar")
      keyClick(Qt.Key_Backspace, Qt.ControlModifier)
      compare(field.text, "foo ")
    }

    function test_ctrlU_clears() {
      type("foo")
      keyClick(Qt.Key_U, Qt.ControlModifier)
      compare(field.text, "")
      compare(root.copied, [])
    }

    function test_list_keys_still_work() {
      type("x")
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Up)
      keyClick(Qt.Key_Return)
      keyClick(Qt.Key_3, Qt.AltModifier)
      compare(root.actions, ["down", "up", "enter", "slot", "paste:slot"], "Alt+3 pastes once Alt is up")
      compare(field.text, "x")
    }

    function test_delete_with_selection_edits_text() {
      type("abc")
      keyClick(Qt.Key_A, Qt.ControlModifier)
      keyClick(Qt.Key_Delete)
      compare(field.text, "")
      compare(root.actions, [])
      keyClick(Qt.Key_Delete)
      compare(root.actions, ["delete"], "without a selection Del deletes the entry")
    }
    function test_ctrlN_is_not_a_shortcut() {
      keyClick(Qt.Key_2, Qt.ControlModifier)
      compare(root.actions, [], "Ctrl+N no longer pastes")
    }

    function test_altN_pastes_on_release() {
      // (QtTest presses/releases the modifier key itself around a key with modifiers.)
      keyPress(Qt.Key_1, Qt.AltModifier)
      keyRelease(Qt.Key_1)
      compare(root.actions, ["slot"], "nothing pasted while Alt is still held")
      keyRelease(Qt.Key_Alt)
      compare(root.actions, ["slot", "paste:slot"], "Alt released: paste, same as Enter")
    }

    function test_pinned_delete_needs_two_presses() {
      root.rowPinned = true
      keyClick(Qt.Key_Delete)
      compare(root.actions, ["arm"], "first Del only arms a pinned row")
      keyClick(Qt.Key_Delete)
      compare(root.actions, ["arm", "delete"], "second Del deletes")
    }

    function test_pinned_delete_cancelled_by_other_key() {
      root.rowPinned = true
      keyClick(Qt.Key_Delete)
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Delete)
      compare(root.actions, ["arm", "down", "arm"], "a move cancels; next Del arms again")
    }

    function test_unpinned_delete_is_immediate() {
      keyClick(Qt.Key_Delete)
      compare(root.actions, ["delete"])
    }
  }
}
