import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Commons as Commons

// Workspace overview overlay. Summon: omarchy-shell shell toggle timon.overview
// Read-only snapshot of Hyprland (hyprctl -j) on every open; actions go
// through hyprctl dispatch.
// Finger sync: the touchpad gesture (hypr show-desktop.lua) writes one line
// "<open|close> <track|commit|cancel> <0..1>" to $XDG_RUNTIME_DIR/timon-overview-gesture
// on every gesture update; this overlay follows it 1:1 (inotify, no process per
// update). Keys and clicks animate the same progress instead.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property var workspaces: []
  property var monitor: ({ x: 0, y: 0, w: 1920, h: 1080 })
  property string monitorName: ""
  property int activeId: -1
  property real progress: 0          // 0 = desktop, 1 = overview
  property bool tracking: false      // fingers on the touchpad drive progress
  property bool closing: false
  property bool loading: false
  property real gestureP: 0
  property int anchorIndex: 0
  readonly property string gesturePath: Quickshell.env("TIMON_OVERVIEW_GESTURE")
    || ((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/timon-overview-gesture")   // env: tests only

  NumberAnimation {
    id: anim
    target: root; property: "progress"
    easing.type: Easing.OutCubic
    property var done: null
    onFinished: { var f = done; done = null; if (f) f() }
  }
  function animateTo(to, done) {
    anim.stop()
    anim.done = done || null
    anim.from = root.progress; anim.to = to
    anim.duration = Math.round(80 + 220 * Math.abs(to - root.progress))
    anim.start()
  }

  function open(payloadJson) {
    if (root.opened || root.loading) return
    var gesture = false
    try { gesture = JSON.parse(payloadJson || "{}").gesture === true } catch (e) {}
    root.tracking = gesture || root.tracking
    root.loading = true
    Hyprland.refreshToplevels()
    snapshot.running = true
  }
  // Animate out (zooming into the anchor tile), then tell the shell.
  function close() {
    if (!root.opened || root.closing) return
    root.closing = true
    root.tracking = false
    root.animateTo(0, function() {
      root.opened = false
      root.closing = false
      if (root.shell && typeof root.shell.hide === "function")
        root.shell.hide((root.manifest && root.manifest.id) || "timon.overview")
    })
  }
  function dismiss() { root.close() }
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
    try { d = JSON.parse(raw) } catch (e) { console.warn("timon.overview: bad hyprctl json", e); root.loading = false; return }
    var mon = null
    for (var i = 0; i < d.m.length; i++) if (d.m[i].focused) mon = d.m[i]
    if (!mon) mon = d.m[0]
    if (!mon) { root.loading = false; return }
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
    root.anchorIndex = Math.max(0, ids.indexOf(root.activeId))
    if (!root.opened) {
      root.loading = false
      root.progress = 0
      root.opened = true
      if (root.tracking) root.progress = root.gestureP
      else root.animateTo(1)
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  property string lastGesture: ""
  function onGesture(line) {
    line = String(line || "").trim()
    if (line === root.lastGesture) return
    root.lastGesture = line
    var f = line.split(/\s+/)
    if (f.length < 3) return
    var dir = f[0], state = f[1], p = Math.max(0, Math.min(1, Number(f[2]) || 0))
    if (dir === "open") {
      if (state === "track") {
        root.gestureP = p
        if (!root.opened && !root.loading) { root.tracking = true; root.open("{\"gesture\":true}") }
        else if (root.opened && !root.closing) { root.tracking = true; anim.stop(); root.progress = p }
      } else if (state === "commit") {
        root.tracking = false
        if (root.opened && !root.closing) root.animateTo(1)
      } else if (state === "cancel") {
        root.tracking = false
        if (root.opened) root.close()
        else root.loading = false
      }
    } else if (dir === "close" && root.opened && !root.closing) {
      if (state === "track") { root.tracking = true; anim.stop(); root.progress = 1 - p }
      else if (state === "commit") root.close()
      else if (state === "cancel") { root.tracking = false; root.animateTo(1) }
    }
  }

  FileView {
    id: gestureFile
    path: root.gesturePath
    watchChanges: true
    blockLoading: true
    printErrors: false
    onFileChanged: { reload(); root.onGesture(text()) }
  }
  // inotify can drop a change that lands right after a reload; while fingers
  // are down, also re-read every 50 ms so a final commit/cancel is never missed.
  Timer {
    interval: 50; repeat: true
    running: root.tracking || root.loading
    onTriggered: { gestureFile.reload(); root.onGesture(gestureFile.text()) }
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
      progress: root.progress
      anchorIndex: root.anchorIndex
      live: root.opened

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
      onFocusWindow: function(address, tileIndex) { root.anchorIndex = tileIndex; root.dismiss(); root.dispatch("hl.dsp.focus({ window = " + root.q("address:" + address) + " })") }
      onSwitchWorkspace: function(id, tileIndex) { root.anchorIndex = tileIndex; root.dismiss(); root.dispatch("hl.dsp.focus({ workspace = " + root.q(id) + " })") }
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
          root.anchorIndex = view.selectedIndex
          root.dismiss(); root.dispatch("hl.dsp.focus({ workspace = " + root.q(id) + " })")
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
          var target = event.key - Qt.Key_0
          for (var t = 0; t < n; t++) if (root.workspaces[t].id === target) root.anchorIndex = t
          root.dismiss(); root.dispatch("hl.dsp.focus({ workspace = " + root.q(target) + " })")
        } else return
        event.accepted = true
      }
    }
  }
}
