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

  function refresh() {
    if (!checkProc.running) checkProc.running = true
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

  Process {
    id: checkProc
    // Exit 0 + first line when the flag exists, exit 1 when it does not.
    command: ["sh", "-c", "[ -e \"$1\" ] || exit 1; head -n1 \"$1\"", "sh", root.flagPath]
    stdout: StdioCollector { id: out }
    onExited: function(exitCode) {
      root.reason = exitCode === 0 ? out.text.trim() : ""
      root.pending = exitCode === 0
    }
  }

  // The helper pings the IPC refresh; this poll is only the fallback.
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
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
