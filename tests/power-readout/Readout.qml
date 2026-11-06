import QtQuick

// Offscreen proof of the 4.5 bar readout fix. This file does not import
// Quickshell, so it can render here. The live widgets are:
//   omarchy-pc-config  timon.pc-power/Panel.qml     "64W" was BarIconButton text
//   omarchy-xps-config timon.xps-power/Panel.qml    watts+percent+icon, slot * 3
// Omarchy 4.5 OpticalGlyph scales BarIconButton.text into a 16 px canvas
// (painted size 12). A label uses Style.font.body (12 px) and hugs the ink.
Window {
  id: win
  width: 760
  height: 520
  visible: true
  color: "#12141c"
  title: "Power readout"

  readonly property string fontName: "DejaVu Sans"
  readonly property int bodyPx: 12
  readonly property int iconFontPx: 13
  readonly property int painted: 12
  readonly property int iconSlot: 27
  readonly property int pad: 4

  function brokenScale(tightW, tightH) {
    return Math.min(painted, 16, 16) / Math.max(tightW, tightH, 1)
  }

  // PC slot was max(unscaled advance, "00W") + 21. XPS with watts was iconSlot * 3.
  readonly property string report: {
    var pcTight = pcMetrics.tightBoundingRect
    var pcScale = brokenScale(pcTight.width, pcTight.height)
    var pcBrokenSlot = Math.ceil(Math.max(pcMetrics.advanceWidth, minMetrics.advanceWidth)) + 21
    var pcFixed = fixedPc.implicitWidth + pad * 2
    var xpsBroken = iconSlot * 3
    var xpsFixed = iconSlot + fixedXps.implicitWidth + pad
    var lines = [
      "pc-broken-slot " + pcBrokenSlot,
      "pc-broken-ink-h " + (pcTight.height * pcScale).toFixed(2),
      "pc-fixed-w " + pcFixed,
      "pc-fixed-h " + fixedPc.implicitHeight,
      "xps-broken-slot " + xpsBroken,
      "xps-fixed-w " + xpsFixed,
      "xps-fixed-h " + fixedXps.implicitHeight,
      "nobattery 0"
    ]
    return lines.join("\n")
  }

  TextMetrics {
    id: pcMetrics
    font.family: win.fontName
    font.pixelSize: win.iconFontPx
    text: "64W"
  }
  TextMetrics {
    id: minMetrics
    font.family: win.fontName
    font.pixelSize: win.iconFontPx
    text: "00W"
  }

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 8

    Text {
      color: "#f4f1ea"
      font.family: win.fontName
      font.pixelSize: 16
      text: "Bar readout: 4.5 optical slot vs body label"
    }

    Repeater {
      model: [
        { kind: "pc", sample: "64W", brokenSlot: 0 },
        { kind: "pc", sample: "8W", brokenSlot: 0 },
        { kind: "pc", sample: "142W", brokenSlot: 0 },
        { kind: "xps", sample: "+4W 80%", brokenSlot: 81 },
        { kind: "xps", sample: "-18W 7%", brokenSlot: 81 },
        { kind: "xps", sample: "0W 80%", brokenSlot: 81 },
        { kind: "xps", sample: "100%", brokenSlot: 54 }
      ]
      Row {
        spacing: 18
        required property var modelData

        Text {
          width: 88
          color: "#c8c2b4"
          font.family: win.fontName
          font.pixelSize: 12
          text: modelData.kind + " " + modelData.sample
        }

        // Broken: the string is scaled into the icon canvas, slot stays wide.
        Rectangle {
          color: "#1c2433"
          border.color: "#5c6b86"
          border.width: 1
          width: modelData.kind === "pc"
            ? Math.ceil(Math.max(sampleMetrics.advanceWidth, minMetrics.advanceWidth)) + 21
            : modelData.brokenSlot
          height: 28
          TextMetrics {
            id: sampleMetrics
            font.family: win.fontName
            font.pixelSize: win.iconFontPx
            text: modelData.sample
          }
          Text {
            anchors.centerIn: parent
            color: "#f4f1ea"
            font.family: win.fontName
            font.pixelSize: win.iconFontPx
            text: modelData.sample
            scale: win.brokenScale(sampleMetrics.tightBoundingRect.width, sampleMetrics.tightBoundingRect.height)
          }
        }

        // Fixed: icon (XPS only) plus a 12 px label, slot hugs the ink.
        Rectangle {
          color: "#1c2433"
          border.color: "#d7c4a1"
          border.width: 1
          height: 28
          width: (modelData.kind === "xps" ? win.iconSlot : 0) + fixedLabel.implicitWidth + win.pad * 2
          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Rectangle {
              visible: modelData.kind === "xps"
              width: win.iconSlot
              height: 28
              color: "transparent"
              Text {
                anchors.centerIn: parent
                color: "#f4f1ea"
                font.family: win.fontName
                font.pixelSize: win.iconFontPx
                text: "▣"
              }
            }
            Text {
              id: fixedLabel
              color: "#f4f1ea"
              font.family: win.fontName
              font.pixelSize: win.bodyPx
              text: modelData.sample
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }

    Text {
      id: fixedPc
      visible: false
      font.family: win.fontName
      font.pixelSize: win.bodyPx
      text: "64W"
    }
    Text {
      id: fixedXps
      visible: false
      font.family: win.fontName
      font.pixelSize: win.bodyPx
      text: "+4W 80%"
    }

    Text {
      color: "#c8c2b4"
      font.family: win.fontName
      font.pixelSize: 12
      text: "Left box: old slot. Right box: body " + win.bodyPx + " px. No battery row is omitted (width 0)."
    }
  }
}
