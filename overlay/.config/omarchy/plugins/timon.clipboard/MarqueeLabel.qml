// From timon.media (MarqueeLabel.qml, same author): elided text that scrolls
// right to left while `running` and the text does not fit.
import QtQuick
import qs.Commons

Item {
  id: root
  property string text: ""
  property color color: "white"
  property string fontFamily: ""
  property int pixelSize: 12
  property bool bold: false
  property bool running: false

  implicitHeight: measure.implicitHeight
  clip: true

  readonly property bool overflow: measure.implicitWidth > width + 1
  readonly property bool scrolling: running && overflow && width > 0
  readonly property real marqueeDistance: copy.implicitWidth + row.spacing
  readonly property int marqueeDuration: Math.max(5000, Math.round(marqueeDistance * 45))

  Text {
    id: measure
    visible: false
    textFormat: Text.PlainText
    text: root.text
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
    font.bold: root.bold
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    textFormat: Text.PlainText
    text: root.text
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
    font.bold: root.bold
    elide: Text.ElideRight
    visible: !root.scrolling
  }

  Row {
    id: row
    spacing: Math.max(Style.space(24), root.width * 0.4)
    anchors.verticalCenter: parent.verticalCenter
    visible: root.scrolling
    x: 0

    Text {
      id: copy
      textFormat: Text.PlainText
      text: root.text
      color: root.color
      font.family: root.fontFamily
      font.pixelSize: root.pixelSize
      font.bold: root.bold
    }

    Text {
      textFormat: Text.PlainText
      text: root.text
      color: root.color
      font.family: root.fontFamily
      font.pixelSize: root.pixelSize
      font.bold: root.bold
    }
  }

  SequentialAnimation {
    id: anim
    running: root.scrolling
    loops: Animation.Infinite
    onRunningChanged: if (!running) row.x = 0

    PauseAnimation { duration: 800 }
    NumberAnimation {
      target: row
      property: "x"
      from: 0
      to: -root.marqueeDistance
      duration: root.marqueeDuration
      easing.type: Easing.Linear
    }
  }

  onTextChanged: if (root.scrolling) {
    row.x = 0
    anim.restart()
  }
}
