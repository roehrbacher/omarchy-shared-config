// Headless idle probe for omarchy-safe-gate: exits once there has been no
// input for IDLE_SECS seconds. Draws nothing.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  IdleMonitor {
    timeout: Number(Quickshell.env("IDLE_SECS") || 15)
    respectInhibitors: false
    onIsIdleChanged: if (isIdle) { console.warn("IDLE"); Qt.exit(0) }
  }
}
