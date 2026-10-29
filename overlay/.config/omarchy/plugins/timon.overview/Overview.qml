import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Commons as Commons

// Workspace overview overlay. Summon: omarchy-shell shell toggle timon.overview
// Read-only snapshot of Hyprland (hyprctl -j) on every open; actions go
// through hyprctl dispatch. Nothing runs while it is closed.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property var workspaces: []
  property var monitor: ({ x: 0, y: 0, w: 1920, h: 1080 })
  property string monitorName: ""
  property int activeId: -1

  function open(payloadJson) {
    if (root.opened) return
    Hyprland.refreshToplevels()
    snapshot.running = true
  }
  function close() { root.opened = false }
  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "timon.overview")
  }
  function toggle() { if (root.opened) root.dismiss(); else root.open("{}") }

  function iconFor(cls) {
    try {
      var e = DesktopEntries.heuristicLookup(cls)
      var name = e && e.icon ? e.icon : cls
      return Quickshell.iconPath(name, true) || ""
    } catch (err) { return "" }
  }

  function toplevelFor(address) {
    var a = String(address).replace(/^0x/, "")
    var list = Hyprland.toplevels.values
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].address).replace(/^0x/, "") === a) return list[i].wayland
    }
    return null
  }

  function load(raw) {
    var d
    try { d = JSON.parse(raw) } catch (e) { console.warn("timon.overview: bad hyprctl json", e); return }
    var mon = null
    for (var i = 0; i < d.m.length; i++) if (d.m[i].focused) mon = d.m[i]
    if (!mon) mon = d.m[0]
    if (!mon) return
    var s = mon.scale || 1
    var rotated = mon.transform % 2 === 1
    root.monitorName = mon.name
    root.monitor = { x: mon.x, y: mon.y,
      w: (rotated ? mon.height : mon.width) / s, h: (rotated ? mon.width : mon.height) / s }
    root.activeId = mon.activeWorkspace.id

    var byId = {}
    for (var c = 0; c < d.c.length; c++) {
      var w = d.c[c]
      if (!w.mapped || w.hidden || w.workspace.id < 1 || w.monitor !== mon.id) continue
      var list = byId[w.workspace.id] || (byId[w.workspace.id] = [])
      list.push({ address: w.address, cls: w.class || w.initialClass || "", title: w.title || "",
        icon: root.iconFor(w.class || w.initialClass || ""),
        x: w.at[0], y: w.at[1], w: w.size[0], h: w.size[1], floating: w.floating, focus: w.focusHistoryID })
    }
    var out = []
    var ids = Object.keys(byId).map(Number).sort(function(a, b) { return a - b })
    for (var k = 0; k < ids.length; k++) {
      var wins = byId[ids[k]].sort(function(a, b) {   // tiled under floating, most recent on top
        if (a.floating !== b.floating) return a.floating ? 1 : -1
        return b.focus - a.focus
      })
      out.push({ id: ids[k], name: String(ids[k]), windows: wins })
    }
    root.workspaces = out
    view.selectedIndex = Math.max(0, ids.indexOf(root.activeId))
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function dispatch(lua) { Quickshell.execDetached(["hyprctl", "dispatch", lua]) }
  function q(s) { return "\"" + String(s).replace(/[^0-9A-Za-z:x]/g, "") + "\"" }

  Process {
    id: snapshot
    command: ["sh", "-c", "printf '{\"c\":%s,\"m\":%s}' \"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\""]
    stdout: StdioCollector { onStreamFinished: root.load(text) }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: {
      var s = Quickshell.screens
      for (var i = 0; i < s.length; i++) if (s[i].name === root.monitorName) return s[i]
      return s.length ? s[0] : null
    }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "timon-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    OverviewView {
      id: view
      anchors.fill: parent
      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 1.04
      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

      workspaces: root.workspaces
      monitor: root.monitor
      activeId: root.activeId
      thumbnails: root.opened
      toplevelFor: root.toplevelFor
      background: Commons.Color.menu.background
      foreground: Commons.Color.menu.text
      accent: Commons.Color.accent
      scrim: Commons.Color.menu.scrim
      fontFamily: Style.font.menuFamily
      radius: Style.cornerRadius

      onDismissRequested: root.dismiss()
      onFocusWindow: function(address) { root.dismiss(); root.dispatch("hl.dsp.focus({ window = " + root.q("address:" + address) + " })") }
      onSwitchWorkspace: function(id) { root.dismiss(); root.dispatch("hl.dsp.focus({ workspace = " + root.q(id) + " })") }
      onMoveWindow: function(address, wsId) {
        root.dispatch("hl.dsp.window.move({ workspace = " + root.q(wsId) + ", follow = false, window = " + root.q("address:" + address) + " })")
        refreshTimer.restart()
      }
    }

    Timer { id: refreshTimer; interval: 120; onTriggered: snapshot.running = true }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) {
        var n = root.workspaces.length
        if (event.key === Qt.Key_Escape) root.dismiss()
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) view.selectedIndex = (view.selectedIndex + 1) % Math.max(1, n)
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) view.selectedIndex = (view.selectedIndex - 1 + n) % Math.max(1, n)
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && n > 0) {
          var id = root.workspaces[view.selectedIndex].id
          root.dismiss(); root.dispatch("hl.dsp.focus({ workspace = " + root.q(id) + " })")
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
          var target = event.key - Qt.Key_0
          root.dismiss(); root.dispatch("hl.dsp.focus({ workspace = " + root.q(target) + " })")
        } else return
        event.accepted = true
      }
    }
  }
}
