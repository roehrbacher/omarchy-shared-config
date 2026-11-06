import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Mirrors the stock omarchy.system-update widget: same button, slot and font,
// hidden (no space) while nothing is pending. Shown while the flag file
// ~/.local/state/omarchy-reload-needed exists; its first line is the tooltip.
BarWidget {
  id: root
  moduleName: "timon.reload-needed"

  readonly property string flagPath: Quickshell.env("HOME") + "/.local/state/omarchy-reload-needed"
  property bool pending: false
  property string reason: ""

  function applyFlag(raw) {
    var line = String(raw || "").split("\n")[0].trim()
    root.reason = line
    root.pending = line.length > 0
  }

  function refresh() {
    flagView.reload()
  }

  function reloadShell() {
    root.pending = false
    if (root.bar) root.bar.run("rm -f \"$HOME/.local/state/omarchy-reload-needed\"; exec omarchy restart shell")
  }

  visible: pending
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onPendingChanged: console.log("timon.reload-needed: pending=" + pending + (pending && reason ? " (" + reason + ")" : ""))

  IpcHandler {
    target: "timon.reload-needed"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  // The flag file is the source of truth. A write shows the icon on the
  // file watch; the helper also calls refresh over shell IPC. No poll timer.
  FileView {
    id: flagView
    path: root.flagPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyFlag(text())
    onFileChanged: reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Quickshell gear-Q logo (white SVG), tinted with the bar foreground.
    iconComponent: Component {
      Item {
        Image {
          id: logo
          anchors.centerIn: parent
          width: Style.font.caption + 1
          height: width
          source: Qt.resolvedUrl("quickshell-logo.svg")
          sourceSize.width: Math.round(width * Screen.devicePixelRatio * 2)
          sourceSize.height: Math.round(height * Screen.devicePixelRatio * 2)
          smooth: true
          mipmap: true
          visible: false
          layer.enabled: true
        }
        MultiEffect {
          anchors.fill: logo
          source: logo
          colorization: 1.0
          colorizationColor: button.foreground
        }
      }
    }
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: root.reason ? "Shell reload needed: " + root.reason : "Shell reload needed"
    onPressed: root.reloadShell()
  }
}
