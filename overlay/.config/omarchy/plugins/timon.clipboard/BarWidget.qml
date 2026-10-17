// Optional bar icon for timon.clipboard (not on the bar by default).
// Left click: open history. Right click: private mode on/off.
// Shows the incognito icon while private mode is on.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "timon.clipboard"

  property bool privateMode: false
  readonly property string statePath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/timon.clipboard/state.json"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.privateMode = JSON.parse(text()).private === true } catch (e) { root.privateMode = false }
    }
    onFileChanged: reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.privateMode ? "󰗹" : "󰅌"
    active: root.privateMode
    tooltipText: root.privateMode ? "Clipboard: private mode (right click to resume)" : "Clipboard history (right click: private mode)"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.bar.run("omarchy-shell shell call timon.clipboard togglePrivate x")
      else root.bar.run("omarchy-shell shell toggle timon.clipboard '{}'")
    }
  }
}
