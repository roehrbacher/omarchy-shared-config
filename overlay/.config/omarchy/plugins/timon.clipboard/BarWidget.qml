// Bar icon for timon.clipboard (fixed-width icon slot, like the other bar icons).
// Left click: open history. Right click: private mode on/off.
// Shows the incognito icon while private mode is on; the tooltip says when
// Flux sync is paused too (flux-pause.sh status, read after each change).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "timon.clipboard"

  property bool privateMode: false
  property bool fluxPaused: false
  readonly property string statePath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/timon.clipboard/state.json"
  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.privateMode = JSON.parse(text()).private === true } catch (e) { root.privateMode = false }
      fluxCheck.left = 3
      fluxCheck.restart()
    }
    onFileChanged: reload()
  }

  // The overlay pauses/resumes Flux a moment after the state changes; check a
  // few times (status only, never changes anything).
  Timer {
    id: fluxCheck
    property int left: 0
    interval: 1500
    onTriggered: {
      if (!fluxStatus.running) fluxStatus.running = true
      if (--left > 0) restart()
    }
  }

  Process {
    id: fluxStatus
    command: [root.pluginDir + "/flux-pause.sh", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.fluxPaused = String(text).trim() === "paused"
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.privateMode ? "󰗹" : "󰅌"
    active: root.privateMode
    tooltipText: root.privateMode ? ("Clipboard: private mode" + (root.fluxPaused ? ", Flux sync paused" : "") + " (right click to resume)") : "Clipboard history (right click: private mode)"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.bar.run("omarchy-shell shell call timon.clipboard togglePrivate x")
      else root.bar.run("omarchy-shell shell toggle timon.clipboard '{}'")
    }
  }
}
