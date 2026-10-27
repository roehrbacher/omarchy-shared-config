import QtQuick
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
// Instant icon: a left click flips the icon at once (optimistic), then the real
// state is read when the click command exits and whenever omarchy-insomnia
// rewrites its state file (FileView watch: picker choices, timer end, CLI).
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
  // Bumped by every left click; a status read started before the latest
  // click is stale and dropped, so it can't undo the optimistic flip.
  property int clickGen: 0
  property bool clickPending: false

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
    // Same rule as `omarchy-insomnia click`: on -> off; off -> laptop 1 h,
    // desktop until turned off.
    var on = !root.active
    root.clickGen++
    root.active = on
    root.countdown = on && root.mode === "laptop" ? "1:00" : ""
    if (clickProc.running) root.clickPending = true
    else clickProc.running = true
  }

  Process {
    id: clickProc
    command: ["omarchy-insomnia", "click"]
    onExited: {
      if (root.clickPending) { root.clickPending = false; running = true; return }
      root.poll()
    }
  }

  Process {
    id: statusProc
    property int gen: 0
    property bool again: false
    command: ["omarchy-insomnia", "status", "--json"]
    onExited: if (again) { again = false; root.poll() }
    stdout: StdioCollector {
      onStreamFinished: {
        // Stale (a click happened since this read started) or a click is
        // still running: keep the optimistic state, the next read confirms.
        if (statusProc.gen !== root.clickGen || clickProc.running) { statusProc.again = true; return }
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
    }
  }

  // Event instead of polling: omarchy-insomnia rewrites this on every change.
  FileView {
    path: root.stateFile
    watchChanges: root.stateFile !== ""
    printErrors: false
    onFileChanged: root.poll()
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
