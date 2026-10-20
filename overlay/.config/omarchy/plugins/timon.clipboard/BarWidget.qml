// Bar icon for timon.clipboard (fixed-width icon slot, like the other bar icons).
// Left click: open history. Right click: incognito on/off.
// Shows the incognito icon while incognito is on. No hover tooltip.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "Bridge.js" as Bridge

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

  // Hand the icon to the overlay so the popup opens right under it.
  Component.onCompleted: Bridge.setAnchor(button, root.bar)
  onBarChanged: Bridge.setAnchor(button, root.bar)
  Component.onDestruction: Bridge.clearAnchor(button)

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.privateMode ? "󰗹" : "󰅌"
    active: root.privateMode
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.bar.run("omarchy-shell shell call timon.clipboard togglePrivate x")
      else if (!Bridge.toggle()) root.bar.run("omarchy-shell shell toggle timon.clipboard '{}'")
    }
  }
}
