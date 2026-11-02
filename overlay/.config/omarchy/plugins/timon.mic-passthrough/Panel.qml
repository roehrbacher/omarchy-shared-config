import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Mic Passthrough: hear your own mic in wired headphones. A small widget next
// to the stock audio panel. Backend: ~/.local/bin/omarchy-audio-passthrough
// (audio-passthrough.service, audio-passthrough.conf ENABLED / VOLUME, devices
// in audio-passthrough.machine.conf). Left click: popup. Right click: on/off.
Panel {
  id: root
  moduleName: "timon.mic-passthrough"
  ipcTarget: "timon.mic-passthrough"

  readonly property string tool: Quickshell.env("HOME") + "/.local/bin/omarchy-audio-passthrough"
  property bool available: false
  property bool isOn: false
  property real volume: 50
  property bool active: false
  property bool headphones: false
  property bool configured: true
  property int editing: 0
  property bool dragging: false
  property real pending: -1

  function apply(text) {
    try { var d = JSON.parse(text) } catch (e) { return }
    root.available = true
    root.isOn = !!d.enabled
    if (!root.dragging && root.pending < 0 && root.editing === 0) root.volume = Number(d.volume) || 0
    root.active = !!d.active
    root.headphones = !!d.headphones
    root.configured = d.configured !== false
  }
  function run(args) { actionProc.command = [root.tool].concat(args); actionProc.running = true }
  function setOn(v) { root.isOn = v; root.run([v ? "on" : "off"]) }
  function queueVolume(v) { root.volume = Math.round(v); root.pending = root.volume; volumeTimer.restart() }
  function statusLine() {
    if (!root.available) return "omarchy-audio-passthrough not found"
    if (!root.configured) return "No headphones set for this machine"
    if (!root.isOn) return "Off"
    if (root.active) return "On: you hear your mic in the headphones"
    if (!root.headphones) return "On, works with wired headphones (USB or jack)"
    return "On, starting…"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "timon.mic-passthrough.switch"
    function toggleOn(): void { root.setOn(!root.isOn) }
  }

  Process { id: statusProc; command: [root.tool, "status"]; stdout: StdioCollector { onStreamFinished: root.apply(text) } }
  Process { id: actionProc; stdout: StdioCollector { onStreamFinished: root.apply(text) } }

  Timer {
    id: volumeTimer
    interval: 150
    onTriggered: {
      if (root.pending < 0) return
      if (actionProc.running) { restart(); return }
      var v = root.pending; root.pending = -1
      root.run(["volume", String(v)])
    }
  }
  // 2 s while the popup is open, 10 s for the bar icon otherwise.
  Timer {
    interval: root.opened ? 2000 : 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running && !actionProc.running && !root.dragging && root.editing === 0) statusProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.isOn ? "󰋎" : "󰋐"
    opacity: root.isOn ? 1.0 : 0.5
    onPressed: function(b) {
      if (b === Qt.RightButton) root.setOn(!root.isOn)
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
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(300))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editing > 0
      onMoveRequested: function(dx, dy) { if (dx !== 0 && root.isOn) root.queueVolume(Math.max(0, Math.min(150, root.volume + dx * 5))) }
      onActivateRequested: root.setOn(!root.isOn)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(6)

        Item {
          width: parent.width
          implicitHeight: Math.max(header.implicitHeight, toggle.implicitHeight)

          PanelSectionHeader {
            id: header
            text: "MIC PASSTHROUGH"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          ToggleSwitch {
            id: toggle
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            checked: root.isOn
            busy: actionProc.running
            foreground: root.bar.foreground
            onToggled: root.setOn(!root.isOn)
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.statusLine()
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          leftPadding: Style.space(6)
        }

        Item {
          width: parent.width
          visible: root.isOn
          implicitHeight: Math.max(slider.implicitHeight, number.implicitHeight)

          PanelSlider {
            id: slider
            bar: root.bar
            anchors.left: parent.left
            anchors.right: number.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            minimum: 0
            maximum: 150
            step: 5
            integer: true
            value: root.volume
            onDraggingChanged: root.dragging = dragging
            onMoved: function(v) { root.queueVolume(v) }
            onReleased: function(v) { root.queueVolume(v) }
          }

          EditableNumber {
            id: number
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            value: root.volume
            minimum: 0
            maximum: 150
            decimals: 0
            suffix: "%"
            color: Qt.darker(root.bar.foreground, 1.4)
            editColor: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onEditingChanged: root.editing += editing ? 1 : -1
            onCommitted: function(next) { root.queueVolume(next) }
          }
        }
      }
    }
  }
}
