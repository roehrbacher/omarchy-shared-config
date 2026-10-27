import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Insomnia as one more stock indicator. Built into timon.indicators by
// omarchy-indicators-build (a clone of omarchy.indicators), so the group
// itself places it: in the inactive row, in list order just before the coffee
// (StayAwake), only revealed on hover; while a session runs it moves into the
// active block next to the clock with the countdown beside it.
// Left click toggles Insomnia (omarchy-insomnia click: laptop on for 1 h, ends on
// its own; desktop on until turned off / off); right click opens the picker.
// Instant icon: a left click flips the icon at once (optimistic) and sends
// `omarchy-insomnia set on|off`; the real state is read whenever
// omarchy-insomnia rewrites its state file (FileView watch: clicks, picker
// choices, timer end, CLI).
// The slow timer is only a safety net and refreshes the countdown.
// On until turned off shows the eye alone (like the coffee); a timed session
// shows its countdown next to it.
Item {
  id: root

  // Injected by the indicators group, like for BarIndicator.
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  property string indicatorBlock: "single"
  property var indicatorHost: null
  property var activeOverride: null

  property bool active: false
  property string countdown: ""
  property string tip: "Insomnia"
  property string mode: ""
  property string stateFile: ""
  // Bumped by every left click. While a click's change is in flight
  // (pending), status reads are ignored so they can't undo the optimistic
  // flip; the change ends with a state file write, which clears pending.
  property int clickGen: 0
  property bool pending: false

  // Same rule as BarIndicator's own visibility. Not button.visible: that is
  // the child's effective visibility, which would latch false with root.
  visible: button.belongsInBlock
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  readonly property string activeTip: (root.countdown !== "" && root.countdown !== "∞"
    ? "Insomnia on (" + root.countdown + " left)" : "Insomnia on") + ": click to stop, right click for options"
  readonly property string inactiveTip: root.tip + (root.mode === "laptop" ? ": click for 1 h" : ": click to turn on") + ", right click for options"

  function poll() {
    if (statusProc.running) { statusProc.again = true; return }
    statusProc.gen = root.clickGen
    statusProc.running = true
  }

  // Countdown next to the eye: only for a timed session ("∞" = until off).
  function countdownFor(s) {
    var t = s && s.active ? String(s.text || "") : ""
    return t === "∞" ? "" : t
  }

  function click(b) {
    if (b === Qt.RightButton) {
      if (root.bar) root.bar.run("omarchy-insomnia menu")
      return
    }
    // Two copies of this file exist while Insomnia is on: the one in the
    // inactive row and the one in the active block (whose icon is forced on).
    // Toggle what this copy SHOWS and send the absolute target (set on|off),
    // never a relative toggle: rapid clicks then always end where the last
    // click pointed. Detached, because turning off removes the active-block
    // copy at once (and a child Process would die with it); the script
    // serializes the changes and rewrites the state file after each one.
    var on = !button.effectiveActive
    root.clickGen++
    root.pending = true
    pendingTimer.restart()
    root.active = on
    root.countdown = on && root.mode === "laptop" ? "1:00" : ""
    Quickshell.execDetached(["omarchy-insomnia", "set", on ? "on" : "off"])
  }

  Process {
    id: statusProc
    property int gen: 0
    property bool again: false
    property string out: ""
    command: ["omarchy-insomnia", "status", "--json"]
    stdout: StdioCollector { onStreamFinished: statusProc.out = String(text || "") }
    onExited: {
      // Read after the output is in; a stale read (a click since it started,
      // or a click still in flight) is dropped and read again later.
      var stale = gen !== root.clickGen || root.pending
      if (!stale) root.apply(out)
      out = ""
      if (again || (stale && !root.pending)) { again = false; root.poll() }
    }
  }

  function apply(text) {
    try {
      var s = JSON.parse(String(text || "").trim())
      root.active = s.active === true
      root.countdown = root.countdownFor(s)
      if (s.tooltip) root.tip = String(s.tooltip)
      if (s.mode) root.mode = String(s.mode)
      if (s.stateFile) root.stateFile = String(s.stateFile)
    } catch (e) {
      root.active = false
      root.countdown = ""
    }
  }

  // Safety net if a change never writes the state file (should not happen).
  Timer {
    id: pendingTimer
    interval: 5000
    onTriggered: { root.pending = false; root.poll() }
  }

  // Event instead of polling: omarchy-insomnia rewrites this on every change.
  FileView {
    path: root.stateFile
    watchChanges: root.stateFile !== ""
    printErrors: false
    onFileChanged: { root.pending = false; pendingTimer.stop(); root.poll() }
  }

  // Safety net + countdown refresh (the countdown shows minutes).
  Timer {
    interval: root.active ? 10000 : 20000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  Row {
    id: row
    spacing: 0

    BarIndicator {
      id: button
      bar: root.bar
      moduleName: root.moduleName
      settings: root.settings
      indicatorBlock: root.indicatorBlock
      indicatorHost: root.indicatorHost
      activeOverride: root.activeOverride
      active: root.active
      activeTooltipText: root.activeTip
      inactiveTooltipText: root.inactiveTip
      iconComponent: Component {
        Item {
          EyeIcon {
            anchors.centerIn: parent
            iconSize: Style.font.caption * 1.05
            color: button.foreground
          }
        }
      }
      onPressed: function(b) { root.click(b) }
    }

    WidgetButton {
      anchors.verticalCenter: parent.verticalCenter
      visible: button.belongsInBlock && button.effectiveActive && root.countdown !== ""
      bar: root.bar
      text: root.countdown
      fontSize: Style.font.caption
      horizontalMargin: 2
      tooltipText: root.activeTip
      onPressed: function(b) { root.click(b) }
    }
  }
}
