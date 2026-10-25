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

  // Same rule as BarIndicator's own visibility. Not button.visible: that is
  // the child's effective visibility, which would latch false with root.
  visible: button.belongsInBlock
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  readonly property string activeTip: (root.countdown !== "" && root.countdown !== "∞"
    ? "Insomnia on (" + root.countdown + " left)" : "Insomnia on") + ": click to stop, right click for options"
  readonly property string inactiveTip: root.tip + (root.mode === "laptop" ? ": click for 1 h" : ": click to turn on") + ", right click for options"

  function poll() { if (!statusProc.running) statusProc.running = true }

  function click(b) {
    if (root.bar) root.bar.run(b === Qt.RightButton
      ? "omarchy-insomnia menu"
      : "omarchy-insomnia click")
    refreshSoon.restart()
  }

  Process {
    id: statusProc
    command: ["omarchy-insomnia", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var s = JSON.parse(String(text || "").trim())
          root.active = s.active === true
          root.countdown = s.active ? String(s.text || "") : ""
          if (s.tooltip) root.tip = String(s.tooltip)
          if (s.mode) root.mode = String(s.mode)
        } catch (e) {
          root.active = false
          root.countdown = ""
        }
      }
    }
  }

  Timer {
    interval: root.active ? 10000 : 20000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  // Re-read for a while after a click (the picker stays open until a choice).
  Timer {
    id: refreshSoon
    interval: 1500
    repeat: true
    property int ticks: 0
    onTriggered: {
      root.poll()
      if (++ticks >= 10) { ticks = 0; stop() }
    }
    onRunningChanged: if (running) ticks = 0
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
