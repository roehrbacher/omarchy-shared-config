import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "timon.audio-passthrough"
  ipcTarget: "timon.audio-passthrough"

  readonly property string tool: Quickshell.env("HOME") + "/.local/bin/omarchy-audio-passthrough"
  property bool enabled_: false
  property real volume: 50
  property bool active: false
  property bool headphones: false
  property bool configured: true
  property string statusError: ""
  property int editingCount: 0
  property real pendingVolume: -1
  property bool dragging: false
  property string source: ""
  property var sources: []
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function refresh() {
    if (statusProc.running || actionProc.running || root.editingCount > 0 || root.dragging)
      return
    statusProc.running = true
  }

  function refreshSources() {
    if (!sourcesProc.running) sourcesProc.running = true
  }

  // Sets the system default input (as the stock audio panel); passthrough follows it.
  function setSource(name) {
    source = name
    run(["source", name])
    refreshSources()
  }

  function applyStatus(text) {
    var data
    try {
      data = JSON.parse(text)
    } catch (e) {
      statusError = "Could not read audio passthrough state"
      return
    }
    statusError = ""
    enabled_ = !!data.enabled
    if (!dragging && pendingVolume < 0)
      volume = data.volume
    active = !!data.active
    headphones = !!data.headphones
    configured = data.configured !== false
    if (data.source !== undefined) source = data.source
  }

  function run(args) {
    actionProc.command = [tool].concat(args)
    actionProc.running = true
  }

  function setEnabled(on) {
    enabled_ = on
    run([on ? "on" : "off"])
  }

  // Slider ticks only queue a value; the timer sends the latest one.
  function queueVolume(v) {
    volume = Math.round(v)
    pendingVolume = volume
    volumeTimer.restart()
  }

  function statusLine() {
    if (statusError !== "") return statusError
    if (!configured) return "No headphones set for this machine (audio-passthrough.machine.conf)"
    if (!enabled_) return "Off"
    if (active) return "On: you hear your mic in the headphones"
    if (!headphones) return "On, but only active on the headphones"
    return "On, starting…"
  }

  Component.onCompleted: { refresh(); refreshSources() }

  Timer {
    id: volumeTimer
    interval: 150
    onTriggered: {
      if (root.pendingVolume < 0) return
      if (actionProc.running) { restart(); return }
      var v = root.pendingVolume
      root.pendingVolume = -1
      root.run(["volume", String(v)])
    }
  }

  Process {
    id: statusProc
    command: [root.tool, "status"]
    stdout: StdioCollector {
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: sourcesProc
    command: [root.tool, "sources"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.sources = JSON.parse(text) } catch (e) {}
      }
    }
  }

  onOpenedChanged: if (opened) { refresh(); refreshSources() }

  Process {
    id: actionProc
    stdout: StdioCollector {
      onStreamFinished: root.applyStatus(text)
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          root.statusError = text.trim()
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: { root.refresh(); if (root.opened) root.refreshSources() }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    bar: root.bar
    text: root.enabled_ ? "󰍬" : "󰍭"
    tooltipText: "Audio passthrough " + (root.enabled_ ? Math.round(root.volume) + "%" + (root.active ? "" : " (headphones only)") : "off") + "\nRight-click: on/off"
    // Dim when off, like Bluetooth's off glyph.
    foreground: root.enabled_ ? (root.bar ? root.bar.barForeground : Color.foreground) : root.dim
    // Right-click toggles passthrough, left-click opens the panel (as Bluetooth does).
    onPressed: function(b) {
      if (b === Qt.RightButton) root.setEnabled(!root.enabled_)
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
    contentWidth: Style.space(320)
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(420))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingCount > 0
      onCloseRequested: root.close()
      onActivateRequested: root.setEnabled(!root.enabled_)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(8)

      Item {
        width: parent.width
        height: Math.max(title.implicitHeight, toggleSwitch.implicitHeight)

        Text {
          id: title
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Audio passthrough"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
        }

        ToggleSwitch {
          id: toggleSwitch
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          checked: root.enabled_
          busy: actionProc.running
          foreground: root.foreground
          onToggled: root.setEnabled(!root.enabled_)
        }
      }

      Text {
        width: parent.width
        text: root.statusLine()
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "Volume"
          color: root.enabled_ ? root.foreground : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        EditableNumber {
          value: root.volume
          minimum: 0
          maximum: 150
          decimals: 0
          suffix: "%"
          color: root.dim
          editColor: root.foreground
          fontFamily: root.fontFamily
          onEditingChanged: root.editingCount += editing ? 1 : -1
          onCommitted: function(next) { root.queueVolume(next) }
        }
      }

      PanelSlider {
        width: parent.width
        bar: root.bar
        minimum: 0
        maximum: 150
        step: 5
        integer: true
        value: root.volume
        onDraggingChanged: root.dragging = dragging
        onMoved: function(next) { root.queueVolume(next) }
        onReleased: function(next) { root.queueVolume(next) }
      }

      PanelSeparator {
        visible: root.sources.length > 0
        foreground: root.foreground
      }

      PanelSectionHeader {
        visible: root.sources.length > 0
        text: "INPUT"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.sources

        SourceRow {
          required property var modelData
          width: column.width
          label: modelData.label
          active: modelData.name === root.source
          onClicked: root.setSource(modelData.name)
        }
      }
    }
    }
  }

  // Same look as the stock audio panel's input rows.
  component SourceRow: CursorSurface {
    id: row
    property string label: ""
    property bool active: false
    signal clicked()
    hasCursor: mouse.containsMouse
    current: active
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: inner.implicitHeight + Style.spacing.xl

    Row {
      id: inner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: "󰍬"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: row.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: row.active
        elide: Text.ElideRight
        width: parent.width - Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.clicked()
    }
  }
}
