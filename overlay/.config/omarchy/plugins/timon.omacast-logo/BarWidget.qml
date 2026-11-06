import QtQuick
import qs.Ui

// Same mark as stock omarchy.menu (logo glyph, omarchy font). Left click
// dispatches the Hyprland global shortcut OmaCast registers (appid omacast,
// name toggle), which is what Super+Space runs: hl.dsp.global("omacast:toggle").
// One dispatch only. Calling the shell IPC as well would toggle twice
// (open, then immediately close). Right click still opens a terminal.
// The stock menu plugin stays loaded; this widget only replaces the bar button.
// Undo: omarchy-bar-replace-id timon.omacast-logo omarchy.menu
BarWidget {
  id: root
  moduleName: "timon.omacast-logo"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function openOmaCast() {
    if (root.bar) root.bar.run("hyprctl dispatch global omacast:toggle")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\ue900"
    fontFamily: "omarchy"
    tooltipText: "OmaCast"
    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.openOmaCast()
    }
  }
}
