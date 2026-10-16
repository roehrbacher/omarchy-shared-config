import QtQuick
import qs.Commons

// A number you can click to type into. Enter or clicking away applies
// (clamped to minimum..maximum), Escape cancels.
Item {
  id: root

  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property int decimals: 2
  property string displayText: value.toFixed(decimals)
  property string suffix: ""
  property color color: Color.foreground
  property color editColor: color
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  readonly property bool editing: input.visible

  signal committed(real value)

  implicitWidth: Math.max(label.implicitWidth, input.visible ? input.contentWidth + Style.space(12) : 0)
  implicitHeight: label.implicitHeight

  function startEdit() {
    input.text = value.toFixed(decimals)
    input.visible = true
    input.forceActiveFocus()
    input.selectAll()
  }

  function finish(apply) {
    if (!input.visible) return
    input.visible = false
    if (!apply) return
    var n = parseFloat(input.text.replace(",", ".").replace("%", ""))
    if (isNaN(n)) return
    n = Math.max(minimum, Math.min(maximum, n))
    var f = Math.pow(10, decimals)
    root.committed(Math.round(n * f) / f)
  }

  Text {
    id: label
    visible: !input.visible
    text: root.displayText + root.suffix
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    font.underline: hover.containsMouse
    anchors.verticalCenter: parent.verticalCenter

    MouseArea {
      id: hover
      anchors.fill: parent
      anchors.margins: -Style.space(4)
      hoverEnabled: true
      cursorShape: Qt.IBeamCursor
      onClicked: root.startEdit()
    }
  }

  Rectangle {
    visible: input.visible
    anchors.fill: input
    anchors.margins: -Style.space(3)
    color: "transparent"
    border.color: root.editColor
    border.width: 1
    radius: 3
  }

  TextInput {
    id: input
    visible: false
    width: Math.max(contentWidth, Style.space(36))
    anchors.verticalCenter: parent.verticalCenter
    color: root.editColor
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    selectByMouse: true
    inputMethodHints: Qt.ImhFormattedNumbersOnly
    Keys.onReturnPressed: function(e) { root.finish(true); e.accepted = true }
    Keys.onEnterPressed: function(e) { root.finish(true); e.accepted = true }
    Keys.onEscapePressed: function(e) { root.finish(false); e.accepted = true }
    onActiveFocusChanged: if (!activeFocus) root.finish(true)
  }
}
