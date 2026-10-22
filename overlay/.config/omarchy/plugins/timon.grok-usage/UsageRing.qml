import QtQuick
import QtQuick.Effects
import qs.Commons

// Grok Bot weekly usage around the logo (local patch, Timon): a 3 px ring
// touching the logo's disc, track visible, used share clockwise from 12.
// Bar foreground normally, bar.active when usage runs ahead of the elapsed
// part of the week. Inputs: grokBotPercent and grokBotExpectedPace.
Item {
  id: v
  property real percent: -1      // 0..1 used, -1 unknown
  property real elapsed: -1      // 0..1 of the usage week gone, -1 unknown
  property color foreground: Color.bar.text
  property color alertColor: Color.bar.active
  property url iconSource

  readonly property int iconStatus: img.status
  readonly property int iconX: iconBox.x
  readonly property int iconY: iconBox.y
  readonly property bool known: percent >= 0
  readonly property bool overPace: known && elapsed >= 0 && percent > elapsed + 0.0001
  readonly property color ringColor: overPace ? alertColor : foreground
  readonly property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
  readonly property int slot: Style.bar.iconSlot
  readonly property int iconSize: Style.bar.iconFont
  // Logo disc radius as a share of the icon's square (SVG viewBox 259, disc 228.5).
  readonly property real discShare: 228.5 / 259 / 2

  implicitWidth: slot
  implicitHeight: slot
  width: implicitWidth
  height: implicitHeight

  Item {
    id: iconBox
    x: Math.round((v.slot - v.iconSize) / 2)
    y: Math.round((v.slot - v.iconSize) / 2)
    width: v.iconSize
    height: v.iconSize

    Image {
      id: img
      anchors.fill: parent
      source: v.iconSource
      objectName: "glanceIcon"
      sourceSize.width: v.iconSize * 2
      sourceSize.height: v.iconSize * 2
      fillMode: Image.PreserveAspectFit
      visible: false
      layer.enabled: true
    }
    MultiEffect {
      anchors.fill: img
      source: img
      colorization: 1.0
      colorizationColor: v.foreground
    }
  }

  Canvas {
    id: ring
    anchors.fill: parent
    antialiasing: true
    readonly property real lw: 3
    readonly property real r: v.iconSize * v.discShare + lw / 2
    property real p: v.known ? Math.max(0, Math.min(1, v.percent)) : 0
    property color c: v.ringColor
    property color t: v.trackColor
    onPChanged: requestPaint()
    onCChanged: requestPaint()
    onTChanged: requestPaint()
    onRChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var cx = iconBox.x + v.iconSize / 2, cy = iconBox.y + v.iconSize / 2
      ctx.lineWidth = lw
      ctx.strokeStyle = t
      ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
      if (p > 0) {
        ctx.strokeStyle = c
        ctx.lineCap = "butt"
        ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * 2 * Math.PI); ctx.stroke()
      }
    }
  }
}
