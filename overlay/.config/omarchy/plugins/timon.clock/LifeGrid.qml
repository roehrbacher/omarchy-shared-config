import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Tim Urban's "Your Life in Weeks": one row per year of age, 52 dots per row.
// Lived weeks are filled, the current week pulses, hovering a dot names the
// week's date and the age you are (or will be) then. When one block of rows
// would make the dots too small, the life splits into two side-by-side halves.
Item {
  id: life

  property date today: new Date()
  property date birth: new Date()
  property int years: 90
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property real dayMs: 86400000
  function birthdayAt(age) { return new Date(birth.getFullYear() + age, birth.getMonth(), birth.getDate(), 12) }
  readonly property int ageYears: {
    var a = today.getFullYear() - birth.getFullYear()
    if (birthdayAt(a) > today) a -= 1
    return Math.max(0, a)
  }
  readonly property int weekInYear: Math.max(0, Math.min(51, Math.floor((today - birthdayAt(ageYears)) / (7 * dayMs))))
  readonly property int lived: ageYears * 52 + weekInYear   // weeks fully behind you
  readonly property int total: years * 52

  // ---- Layout: pick 1 or 2 blocks, whichever gives bigger dots.
  readonly property real headerH: header.implicitHeight + Style.space(8)
  readonly property real areaW: width
  readonly property real areaH: Math.max(1, height - headerH)
  function pitchFor(k) {
    var rows = Math.ceil(years / k)
    var decadeGaps = Math.floor((rows - 1) / 10)
    var blockGap = 3   // in pitches
    var pw = areaW / (52 * k + blockGap * (k - 1))
    var ph = areaH / (rows + decadeGaps * 0.6)
    return Math.min(pw, ph)
  }
  readonly property int blocks: pitchFor(2) > pitchFor(1) ? 2 : 1
  readonly property real pitch: Math.floor(pitchFor(blocks) * 4) / 4
  readonly property int rowsPerBlock: Math.ceil(years / blocks)
  readonly property real dot: Math.max(1.5, pitch * 0.72)
  readonly property real blockW: 52 * pitch
  readonly property real gridW: blockW * blocks + (blocks - 1) * 3 * pitch
  readonly property real gridH: rowsPerBlock * pitch + Math.floor((rowsPerBlock - 1) / 10) * pitch * 0.6
  readonly property real gridX: Math.round((width - gridW) / 2)
  readonly property real gridY: headerH + Math.round((areaH - gridH) / 2)

  function cellX(row, col) { return gridX + Math.floor(row / rowsPerBlock) * (blockW + 3 * pitch) + col * pitch }
  function cellY(row) { var r = row % rowsPerBlock; return gridY + r * pitch + Math.floor(r / 10) * pitch * 0.6 }

  function cellAt(px, py) {
    for (var b = 0; b < blocks; b++) {
      var bx = gridX + b * (blockW + 3 * pitch)
      if (px < bx || px >= bx + blockW) continue
      var col = Math.floor((px - bx) / pitch)
      for (var r = 0; r < rowsPerBlock; r++) {
        var y = cellY(r)
        if (py >= y && py < y + pitch) {
          var row = b * rowsPerBlock + r
          return row < years ? { row: row, col: col } : null
        }
      }
    }
    return null
  }

  readonly property color livedColor: Style.selectedStateColor(foreground, Commons.Color.accent)
  readonly property color futureColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)

  onLivedChanged: canvas.requestPaint()
  onYearsChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onForegroundChanged: canvas.requestPaint()

  // ---- Header rail: same small caps as the year/life rails in month view.
  Item {
    id: header
    width: parent.width
    implicitHeight: headLeft.implicitHeight

    Text {
      id: headLeft
      anchors.left: parent.left
      text: "AGE " + life.ageYears
      color: Qt.darker(life.foreground, 1.5)
      font.family: life.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 1
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "WEEK " + (life.lived + 1).toLocaleString(Qt.locale("en_US"), "f", 0) + " OF " + life.total.toLocaleString(Qt.locale("en_US"), "f", 0)
      color: Qt.darker(life.foreground, 1.5)
      font.family: life.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 1
    }
    Text {
      anchors.right: parent.right
      text: Math.floor(100 * life.lived / Math.max(1, life.total)) + "%"
      color: life.foreground
      font.family: life.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var d = life.dot, off = (life.pitch - d) / 2, r = d / 2
      for (var row = 0; row < life.years; row++) {
        var y = life.cellY(row) + off
        for (var col = 0; col < 52; col++) {
          var i = row * 52 + col
          ctx.fillStyle = i < life.lived ? life.livedColor : life.futureColor
          ctx.beginPath()
          ctx.arc(life.cellX(row, col) + off + r, y + r, r, 0, 2 * Math.PI)
          ctx.fill()
        }
      }
    }
  }

  // ---- This week: a glowing dot that breathes.
  Rectangle {
    id: nowDot
    readonly property int row: Math.floor(life.lived / 52)
    readonly property int col: life.lived % 52
    visible: row < life.years
    width: life.pitch * 1.5
    height: width
    radius: width / 2
    x: life.cellX(row, col) + life.pitch / 2 - width / 2
    y: life.cellY(row) + life.pitch / 2 - height / 2
    color: Commons.Color.accent

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 2.2
      height: width
      radius: width / 2
      color: "transparent"
      border.width: Math.max(1, life.pitch * 0.35)
      border.color: Commons.Color.accent
      opacity: glow.v
      scale: 0.6 + 0.4 * (1 - glow.v)
    }
    QtObject { id: glow; property real v: 0.8 }
    SequentialAnimation {
      running: life.visible && nowDot.visible
      loops: Animation.Infinite
      NumberAnimation { target: glow; property: "v"; from: 0.8; to: 0.0; duration: 1400; easing.type: Easing.OutCubic }
      PauseAnimation { duration: 300 }
    }
  }

  // ---- Hover: date of that week and the age then.
  Rectangle {
    id: hoverRing
    property var cell: null
    visible: cell !== null && hoverMouse.containsMouse
    width: life.pitch + 2
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: life.foreground
    x: cell ? life.cellX(cell.row, cell.col) - 1 : 0
    y: cell ? life.cellY(cell.row) - 1 : 0
  }

  MouseArea {
    id: hoverMouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onPositionChanged: function(m) { hoverRing.cell = life.cellAt(m.x, m.y) }
    onExited: hoverRing.cell = null

    PanelToolTip {
      id: tip
      delay: 0
      visible: hoverRing.visible
      x: hoverRing.x + hoverRing.width / 2 - width / 2
      y: hoverRing.y - height - Style.space(6)
      fontFamily: life.fontFamily
      text: {
        var c = hoverRing.cell
        if (!c) return ""
        var start = new Date(life.birthdayAt(c.row).getTime() + c.col * 7 * life.dayMs)
        var idx = c.row * 52 + c.col
        var when = idx < life.lived ? "" : (idx === life.lived ? "  ·  this week" : "")
        return "Week of " + Qt.formatDate(start, "d MMM yyyy") + "  ·  age " + c.row + when
      }
    }
  }
}
