import QtQuick
import QtQuick.Effects
import qs.Commons

// Grok Bot weekly usage at a glance (local patch, Timon). Four trial looks,
// shown side by side via the "glanceVariants" setting (e.g. "1,2,3,4"):
//   1  progress ring around the icon + up to 7 dots under it (days left)
//   2  progress ring + small "Nd" text (days left)
//   3  two tiny bars under the icon: usage, time left in the week
//   4  progress ring, bar foreground normally, bar.active (urgent) when
//      usage runs ahead of the elapsed part of the week
// "Hugging" looks, all with 4's pace colour (ring touches the logo's disc;
// the logo is a disc filling 228.5/259 of its square, eyes cut out):
//   5  thin ring touching the disc edge (no gap)
//   6  thin ring inset, centred on the disc edge (overlaps it)
//   7  look 4's ring, logo scaled up to fill the ring's inner edge
//   8  no ring: the logo's disc is the gauge (dim disc, used part bright)
//   9  thick 3 px ring touching the disc, track visible
// Inputs are the plugin's real data: grokBotPercent, grokBotResetAt and
// grokBotPeriodStart (from cursor_usage_scanner.py --include-sand).
Item {
  id: v
  property int variant: 1
  property real percent: -1      // 0..1 used, -1 unknown
  property real elapsed: -1      // 0..1 of the usage week gone, -1 unknown
  property real daysLeft: -1     // days until reset
  property string resetText: ""  // "4d" / "11h", the plugin's own format
  property color foreground: Color.bar.text
  property color alertColor: Color.bar.active
  property url iconSource
  property string fontFamily: Style.font.family

  readonly property int iconStatus: img.status
  readonly property int iconX: iconBox.x
  readonly property int iconY: iconBox.y
  readonly property bool known: percent >= 0
  readonly property bool overPace: known && elapsed >= 0 && percent > elapsed + 0.0001
  readonly property color ringColor: variant >= 4 && overPace ? alertColor : foreground
  readonly property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
  readonly property int slot: Style.bar.iconSlot
  // Logo disc radius as a share of the icon's square (SVG viewBox 259, disc 228.5).
  readonly property real discShare: 228.5 / 259 / 2
  readonly property int baseIcon: Style.bar.iconFont
  // Look 7: icon grows until its disc meets look 4's ring inner edge.
  // (Same size as that ring, so both share one pixel centre; the disc then
  // reaches the ring's stroke.)
  readonly property int iconSize: variant === 7 ? baseIcon + 8 : baseIcon
  readonly property bool ringed: variant === 1 || variant === 2 || variant === 4 || variant === 7
  readonly property bool hugging: variant === 5 || variant === 6 || variant === 9
  // Ring 4 px wider than the icon on each side; variant 1 sits higher to
  // leave a row for the dots.
  readonly property int ringSize: (variant === 7 ? baseIcon : iconSize) + 8
  readonly property real iconCenterY: variant === 1 ? slot / 2 - 2 : (variant === 3 ? slot / 2 - 3 : slot / 2)

  implicitWidth: variant === 2 ? slot + Math.ceil(daysText.implicitWidth) + 1 : slot
  implicitHeight: slot
  width: implicitWidth
  height: implicitHeight

  Item {
    id: iconBox
    visible: v.variant !== 8
    x: Math.round((v.slot - v.iconSize) / 2)
    y: Math.round(v.iconCenterY - v.iconSize / 2)
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
    visible: v.ringed
    x: Math.round(v.slot / 2 - v.ringSize / 2)
    y: Math.round(v.iconCenterY - v.ringSize / 2)
    width: v.ringSize
    height: v.ringSize
    antialiasing: true
    property real p: v.known ? Math.max(0, Math.min(1, v.percent)) : 0
    property color c: v.ringColor
    property color t: v.trackColor
    onPChanged: requestPaint()
    onCChanged: requestPaint()
    onTChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var r = width / 2 - 1
      ctx.lineWidth = 1.5
      ctx.strokeStyle = t
      ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke()
      if (p > 0) {
        ctx.strokeStyle = c
        ctx.lineCap = "round"
        ctx.beginPath(); ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + p * 2 * Math.PI); ctx.stroke()
      }
    }
  }

  // Looks 5, 6, 9: ring around the disc, centred on the icon's own centre.
  Canvas {
    id: hug
    visible: v.hugging
    anchors.fill: parent
    antialiasing: true
    readonly property real lw: v.variant === 9 ? 3 : 1.5
    readonly property real disc: v.iconSize * v.discShare
    // 5/9 touch the disc from outside, 6 sits on its edge.
    readonly property real r: v.variant === 6 ? disc : disc + lw / 2
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
        ctx.lineCap = v.variant === 9 ? "butt" : "round"
        ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + p * 2 * Math.PI); ctx.stroke()
      }
    }
  }

  // Look 8: the logo itself is the gauge. Dim logo, then the bright logo
  // masked by a pie of the used share (clockwise from 12 o'clock).
  Item {
    id: gauge
    visible: v.variant === 8
    x: iconBox.x; y: iconBox.y
    width: v.iconSize; height: v.iconSize
    Image {
      id: gImg
      anchors.fill: parent
      source: v.iconSource
      sourceSize.width: v.iconSize * 2
      sourceSize.height: v.iconSize * 2
      fillMode: Image.PreserveAspectFit
      visible: false
      layer.enabled: true
    }
    MultiEffect {
      anchors.fill: gImg
      source: gImg
      colorization: 1.0
      colorizationColor: v.trackColor
    }
    Canvas {
      id: pie
      anchors.fill: parent
      visible: false
      layer.enabled: true
      property real p: v.known ? Math.max(0, Math.min(1, v.percent)) : 0
      onPChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (p <= 0) return
        ctx.fillStyle = "#ffffff"
        ctx.beginPath(); ctx.moveTo(width / 2, height / 2)
        ctx.arc(width / 2, height / 2, width, -Math.PI / 2, -Math.PI / 2 + p * 2 * Math.PI)
        ctx.closePath(); ctx.fill()
      }
    }
    MultiEffect {
      objectName: "gaugeFill"
      anchors.fill: gImg
      source: gImg
      colorization: 1.0
      colorizationColor: v.ringColor
      maskEnabled: true
      maskSource: pie
      maskThresholdMin: 0.5
      maskSpreadAtMin: 0.2
    }
  }

  // Variant 1: one dot per day left (rounded up, max 7).
  Row {
    visible: v.variant === 1 && v.daysLeft >= 0
    spacing: 1
    anchors.horizontalCenter: parent.horizontalCenter
    y: v.slot - 3
    Repeater {
      model: v.daysLeft >= 0 ? Math.min(7, Math.ceil(v.daysLeft)) : 0
      Rectangle { width: 2; height: 2; radius: 1; color: v.foreground }
    }
  }

  // Variant 2: days left as text next to the ring.
  Text {
    id: daysText
    visible: v.variant === 2
    x: v.slot - 2
    anchors.verticalCenter: parent.verticalCenter
    text: v.resetText
    color: Qt.darker(v.foreground, 1.55)
    font.family: v.fontFamily
    font.pixelSize: Style.font.caption
    renderType: Text.NativeRendering
  }

  // Variant 3: usage bar, then time-left-in-week bar.
  Column {
    visible: v.variant === 3
    spacing: 2
    x: Math.round((v.slot - (v.iconSize + 4)) / 2)
    y: Math.round(iconBox.y + v.iconSize + 3)
    Repeater {
      model: [v.known ? v.percent : 0, v.elapsed >= 0 ? 1 - v.elapsed : 0]
      Item {
        required property real modelData
        width: v.iconSize + 4
        height: 2
        Rectangle { anchors.fill: parent; radius: 1; color: v.trackColor }
        Rectangle { width: Math.round(parent.width * Math.max(0, Math.min(1, modelData))); height: 2; radius: 1; color: v.foreground }
      }
    }
  }
}
