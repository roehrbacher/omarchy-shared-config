import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Local AI: skull and crossbones in the bar while one of your own models
// (a llama.cpp systemd user service) is running. Click for a panel with one
// switch per model; right-click loads/unloads the running or first model. Models come from ~/.config/omarchy/local-ai.json (plus
// auto-discovered llama-*.service units); local-ai.py does the systemctl work.
// Downloaded .gguf files that no model unit uses yet are listed below them
// (read only), so a new download shows up before it is set up to run.
Panel {
  id: root
  moduleName: "timon.local-ai"
  ipcTarget: "timon.local-ai"
  manageIpc: false

  // Nerd Font (Material Design) glyphs, present in JetBrainsMono Nerd Font.
  readonly property string glyphOn: String.fromCodePoint(0xF0BC6)   // md-skull_crossbones
  readonly property string glyphOff: String.fromCodePoint(0xF0BC7)  // md-skull_crossbones_outline

  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("local-ai.py")).replace(/^file:\/\//, ""))

  property var models: []
  property var files: []
  property bool exclusive: true
  property string configError: ""
  property string actionError: ""
  // unit -> { want: "on"|"off", since: ms } until systemd catches up
  property var pending: ({})
  property int cursorIndex: 0
  property bool cursorActive: false
  property real pulse: 1.0

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function modelOn(m) { return m.state === "on" || m.state === "loading" }
  function wanted(m) {
    var p = pending[m.unit]
    return p ? p.want === "on" : modelOn(m)
  }
  function busy(m) { return !!pending[m.unit] || m.state === "loading" || m.state === "stopping" }

  readonly property var runningModel: {
    for (var i = 0; i < models.length; i++) if (models[i].state === "on") return models[i]
    return null
  }
  readonly property var loadingModel: {
    for (var i = 0; i < models.length; i++) if (models[i].state === "loading") return models[i]
    for (var u in pending) if (pending[u].want === "on") {
      for (var j = 0; j < models.length; j++) if (models[j].unit === u) return models[j]
    }
    return null
  }
  readonly property bool anyActive: {
    for (var i = 0; i < models.length; i++) if (modelOn(models[i])) return true
    return false
  }
  readonly property bool loading: loadingModel !== null || Object.keys(pending).length > 0
  readonly property string barGlyph: anyActive || loadingModel !== null ? glyphOn : glyphOff
  readonly property color barIconColor: anyActive || loadingModel !== null ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property string summary: {
    if (loadingModel) return "Loading " + loadingModel.name
    if (runningModel) return runningModel.name + " running"
    return "No local model running"
  }

  function statusText(m) {
    var p = pending[m.unit]
    if (p && p.want === "on" && m.state !== "loading") return "Starting…"
    if (p && p.want === "off") return "Stopping…"
    if (m.state === "on") return m.detail !== "" ? "Running · " + m.detail : "Running"
    if (m.state === "loading") return "Loading model…"
    if (m.state === "stopping") return "Stopping…"
    if (m.state === "failed") return "Failed — check the service log"
    return "Off"
  }

  function applyState(text) {
    var data
    try { data = JSON.parse(String(text).trim()) } catch (e) { configError = "local-ai.py: no output"; return }
    exclusive = data.exclusive !== false
    configError = data.error || ""
    models = data.models || []
    files = data.files || []
    var next = {}
    var now = Date.now()
    for (var u in pending) {
      var m = null
      for (var i = 0; i < models.length; i++) if (models[i].unit === u) m = models[i]
      if (!m) continue
      var done = pending[u].want === "on" ? (m.state === "on" || m.state === "loading" || m.state === "failed")
                                          : (m.state === "off" || m.state === "failed")
      if (!done && now - pending[u].since < 60000) next[u] = pending[u]
    }
    pending = next
    if (cursorIndex >= models.length) cursorIndex = Math.max(0, models.length - 1)
  }

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function setModel(unit, on) {
    var next = {}
    for (var u in pending) next[u] = pending[u]
    next[unit] = { want: on ? "on" : "off", since: Date.now() }
    if (on && exclusive) {
      for (var i = 0; i < models.length; i++)
        if (models[i].unit !== unit && modelOn(models[i])) next[models[i].unit] = { want: "off", since: Date.now() }
    }
    pending = next
    actionError = ""
    actionProc.command = ["python3", helper, on ? "start" : "stop", unit]
    actionProc.running = true
  }

  function toggleModel(m) {
    if (!m || actionProc.running) return
    setModel(m.unit, !wanted(m))
  }

  // Model a right-click acts on: the one loading or running, else the first
  // listed (the default). Same toggle path as the popup switch.
  readonly property var quickModel: loadingModel || runningModel || (models.length > 0 ? models[0] : null)
  function quickToggle() { toggleModel(quickModel) }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Component.onCompleted: refresh()

  Process {
    id: stateProc
    command: ["python3", root.helper, "state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text).trim() !== "") root.actionError = String(text).trim()
    }
    onExited: function(code) {
      if (code !== 0 && root.actionError === "") root.actionError = "systemctl failed (" + code + ")"
      root.refresh()
    }
  }

  // Fast while something is changing or the panel is open, slow otherwise.
  Timer {
    interval: root.loading || root.opened ? 1500 : 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  SequentialAnimation on pulse {
    running: root.loading
    loops: Animation.Infinite
    alwaysRunToEnd: false
    NumberAnimation { from: 1.0; to: 0.35; duration: 700; easing.type: Easing.InOutSine }
    NumberAnimation { from: 0.35; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
    onRunningChanged: if (!running) root.pulse = 1.0
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function start(unit: string): string { root.setModel(unit, true); return "ok" }
    function stop(unit: string): string { root.setModel(unit, false); return "ok" }
    function quickToggle(): string { root.quickToggle(); return root.quickModel ? root.quickModel.unit : "none" }
    function status(): string {
      return JSON.stringify({ active: root.anyActive, loading: root.loading, summary: root.summary,
                              exclusive: root.exclusive, models: root.models, files: root.files, pending: root.pending,
                              error: root.configError || root.actionError })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barGlyph
    foreground: root.barIconColor
    opacity: root.loading ? root.pulse : 1.0
    tooltipText: root.summary
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else if (buttonCode === Qt.RightButton) root.quickToggle()
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0 && root.models.length > 0)
          root.cursorIndex = Math.max(0, Math.min(root.models.length - 1, root.cursorIndex + dy))
      }
      onActivateRequested: if (root.cursorActive && root.models.length > 0) root.toggleModel(root.models[root.cursorIndex])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Local AI"
          meta: root.summary
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.anyActive ? 1.0 : 0.5
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.anyActive || root.loadingModel !== null ? root.glyphOn : root.glyphOff
              color: root.foreground
              opacity: root.loading ? root.pulse : 1.0
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: text !== ""
          width: parent.width
          text: root.actionError !== "" ? root.actionError : root.configError
          color: root.bar ? root.bar.urgent : Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: root.exclusive && root.models.length > 1 ? "MODELS · ONE AT A TIME" : "MODELS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            textFormat: Text.PlainText
            visible: root.models.length === 0
            width: parent.width
            text: root.files.length > 0 ? "None set up to run yet. Add one to ~/.config/omarchy/local-ai.json"
                                        : "No models. Add one to ~/.config/omarchy/local-ai.json"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: root.models
            Toggle {
              required property var modelData
              required property int index
              width: parent.width
              label: modelData.name
              description: root.statusText(modelData)
              checked: root.wanted(modelData)
              hasCursor: root.cursorActive && root.cursorIndex === index
              foreground: root.foreground
              fontFamily: root.fontFamily
              onHovered: function(on) { if (on) { root.cursorActive = true; root.cursorIndex = index } }
              onClicked: root.toggleModel(modelData)
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.files.length > 0

          PanelSectionHeader {
            text: "DOWNLOADED · NOT SET UP TO RUN"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.files
            Column {
              required property var modelData
              width: parent.width
              spacing: Style.spacing.xs

              Text {
                textFormat: Text.PlainText
                text: modelData.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.sizeGB + " GB · " + String(modelData.path).replace(/^\/home\/[^\/]+/, "~")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideMiddle
                width: parent.width
              }
            }
          }
        }
      }
    }
  }
}
