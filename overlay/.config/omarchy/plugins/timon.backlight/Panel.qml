import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Backlight: auto brightness and keyboard backlight, next to the stock
// display panel. On the bar only where ~/.local/bin/omarchy-auto-brightness is
// installed or a keyboard backlight (/sys/class/leds/*kbd_backlight*) exists.
// Left click: popup. Right click: auto brightness on/off.
Panel {
  id: root
  moduleName: "timon.backlight"
  ipcTarget: "timon.backlight"

  // ---- Auto brightness: `omarchy-auto-brightness status|on|off|set min|max|keyboard` ----
  readonly property string autoTool: Quickshell.env("HOME") + "/.local/bin/omarchy-auto-brightness"
  property bool autoAvailable: false
  property bool dragging: false
  property var autoSt: ({ enabled: false, min: 8, max: 100, keyboard: true, mode: "not running" })
  function autoApply(text) {
    try { root.autoSt = JSON.parse(text); root.autoAvailable = true } catch (e) {}
  }
  function autoRun(args) {
    if (!root.autoAvailable || autoActionProc.running) return
    autoActionProc.command = [root.autoTool].concat(args)
    autoActionProc.running = true
  }
  function autoStatusLine() {
    var st = root.autoSt, m = st.mode || ""
    var lux = st.lux === null || st.lux === undefined ? "" : " · " + Math.round(st.lux) + " lx"
    if (m === "auto" && !st.offset) return "Following the light sensor" + lux
    if (m === "auto" && st.offset) return "Following the light sensor" + lux + " · your offset " + (st.offset > 0 ? "+" : "") + st.offset + "%"
    if (m === "walk-away dim") return "Held by the walk-away lock" + lux
    if (m === "off") return "Off" + lux
    if (m === "not running") return "Service not running"
    return "Waiting (" + m + ")" + lux
  }

  // ---- Keyboard backlight: first /sys/class/leds/*kbd_backlight* ----
  property string kbdDevice: ""
  property int kbdValue: 0
  property int kbdMax: 0
  function kbdApply(text) {
    var p = String(text).trim().split(/\s+/)
    if (p.length < 3) { root.kbdDevice = ""; return }
    root.kbdDevice = p[0]
    if (!root.dragging) root.kbdValue = parseInt(p[1]) || 0
    root.kbdMax = parseInt(p[2]) || 0
  }
  function kbdSet(v) {
    root.kbdValue = Math.round(v)
    Quickshell.execDetached(["brightnessctl", "-q", "-d", root.kbdDevice, "set", String(root.kbdValue)])
  }

  readonly property bool shown: autoAvailable || (kbdDevice !== "" && kbdMax > 0)
  visible: shown
  implicitWidth: shown ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  // Nothing is started where the tool is missing (no "failed to start" logs).
  Process { id: autoStatusProc; command: ["sh", "-c", 'test -x "$1" && exec "$1" status', "sh", root.autoTool]; stdout: StdioCollector { onStreamFinished: root.autoApply(text) } }
  Process { id: autoActionProc; stdout: StdioCollector { onStreamFinished: root.autoApply(text) } }
  Process {
    id: kbdProc
    command: ["sh", "-c", 'for d in /sys/class/leds/*kbd_backlight*; do [ -e "$d" ] && echo "${d##*/} $(cat "$d/brightness") $(cat "$d/max_brightness")"; break; done']
    stdout: StdioCollector { onStreamFinished: root.kbdApply(text) }
  }
  // Once at start (to learn what exists), then 1.5 s while open, 30 s otherwise.
  Timer {
    interval: root.opened ? 1500 : 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (root.dragging) return
      if (!autoStatusProc.running && !autoActionProc.running) autoStatusProc.running = true
      if (!kbdProc.running) kbdProc.running = true
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.autoAvailable ? "󰃡" : "󰌌"
    opacity: !root.autoAvailable || root.autoSt.enabled ? 1.0 : 0.5
    onPressed: function(b) {
      if (b === Qt.RightButton) root.autoRun([root.autoSt.enabled ? "off" : "on"])
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(6)

        // ---------- Auto brightness ----------
        Item {
          visible: root.autoAvailable
          width: parent.width
          implicitHeight: Math.max(autoHeader.implicitHeight, autoSwitch.implicitHeight)
          PanelSectionHeader {
            id: autoHeader
            text: "AUTO BRIGHTNESS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }
          ToggleSwitch {
            id: autoSwitch
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            checked: root.autoSt.enabled
            busy: autoActionProc.running
            foreground: root.bar.foreground
            onToggled: root.autoRun([root.autoSt.enabled ? "off" : "on"])
          }
        }

        Text {
          visible: root.autoAvailable
          width: parent.width
          leftPadding: Style.space(6)
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: root.autoStatusLine()
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        LabeledSlider {
          visible: root.autoAvailable
          prefix: "Minimum "; suffix: "%"
          minimum: 1; maximum: 100; value: root.autoSt.min
          onPicked: function(v) { root.autoRun(["set", "min", String(Math.round(Math.min(v, root.autoSt.max)))]) }
        }
        LabeledSlider {
          visible: root.autoAvailable
          prefix: "Maximum "; suffix: "%"
          minimum: 1; maximum: 100; value: root.autoSt.max
          onPicked: function(v) { root.autoRun(["set", "max", String(Math.round(Math.max(v, root.autoSt.min)))]) }
        }

        // ---------- Keyboard backlight ----------
        PanelSeparator {
          visible: root.autoAvailable && root.kbdDevice !== ""
          foreground: root.bar.foreground
        }

        PanelSectionHeader {
          visible: root.kbdDevice !== ""
          text: "KEYBOARD BACKLIGHT"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        LabeledSlider {
          visible: root.kbdDevice !== "" && root.kbdMax > 0
          prefix: "Level "; suffix: " / " + root.kbdMax
          minimum: 0; maximum: Math.max(1, root.kbdMax); value: root.kbdValue
          onPicked: function(v) { root.kbdSet(v) }
        }

        Item {
          visible: root.autoAvailable && root.kbdDevice !== ""
          width: parent.width
          implicitHeight: Math.max(kbdLabel.implicitHeight, kbdSwitch.implicitHeight) + Style.space(4)
          Text {
            id: kbdLabel
            anchors.left: parent.left
            anchors.leftMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Turn on automatically in the dark"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
          ToggleSwitch {
            id: kbdSwitch
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            checked: root.autoSt.keyboard
            busy: autoActionProc.running
            foreground: root.bar.foreground
            onToggled: root.autoRun(["set", "keyboard", root.autoSt.keyboard ? "off" : "on"])
          }
        }
      }
    }
  }

  component LabeledSlider: Column {
    id: ls
    property string prefix: ""
    property string suffix: ""
    property real minimum: 0
    property real maximum: 100
    property real value: 0
    signal picked(real v)
    width: column.width
    spacing: Style.space(4)
    Text {
      leftPadding: Style.space(6)
      textFormat: Text.PlainText
      text: ls.prefix + Math.round(slider.dragging ? slider.liveValue : ls.value) + ls.suffix
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }
    PanelSlider {
      id: slider
      bar: root.bar
      x: Style.space(6)
      width: parent.width - Style.space(12)
      minimum: ls.minimum; maximum: ls.maximum; step: 1; integer: true
      value: ls.value
      onDraggingChanged: root.dragging = dragging
      onReleased: function(v) { ls.picked(v) }
    }
  }
}
