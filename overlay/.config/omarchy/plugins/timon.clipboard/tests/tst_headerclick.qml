// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_headerclick.qml
// The popup header's layering: a collapsed search button with a full-row,
// invisible TextInput declared after it (as in Clipboard.qml). The button
// needs z above the field to get the click.
import QtQuick
import QtTest

Item {
  id: root
  width: 400; height: 40
  property int clicks: 0
  property bool buttonZ: true

  Rectangle {
    id: button
    z: root.buttonZ ? 2 : 0
    anchors.right: parent.right
    width: 40; height: 40
    MouseArea { anchors.fill: parent; onClicked: root.clicks++ }
  }
  TextInput {
    id: field
    anchors.fill: parent
    opacity: 0
    focus: true
    selectByMouse: true
  }

  TestCase {
    name: "HeaderClick"
    when: windowShown
    function test_buttonGetsClickWithZ() {
      root.buttonZ = true; root.clicks = 0
      for (var i = 0; i < 5; i++) mouseClick(root, 380, 20)
      compare(root.clicks, 5)
    }
    function test_withoutZTheFieldEatsIt() {
      root.buttonZ = false; root.clicks = 0
      mouseClick(root, 380, 20)
      compare(root.clicks, 0, "reproduces the 1.10.1 bug")
      root.buttonZ = true
    }
  }
}
