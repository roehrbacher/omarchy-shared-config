import Quickshell
import QtQuick
import qs.Commons
// Offscreen render of the four glance variants on a bar-coloured strip.
// Real numbers from the scanner are passed in via env (GLANCE_P/E/D/R).
ShellRoot {
  id: shell
  readonly property real p: Number(Quickshell.env("GLANCE_P") || 0.71)
  readonly property real e: Number(Quickshell.env("GLANCE_E") || 0.37)
  readonly property real d: Number(Quickshell.env("GLANCE_D") || 4.5)
  readonly property string r: Quickshell.env("GLANCE_R") || "4d"
  // Offscreen the theme isn't loaded, so use the theme's colours from env
  // (GLANCE_FG/BG/ALERT), stock Omarchy defaults otherwise.
  readonly property color fg: Quickshell.env("GLANCE_FG") || "#cacccc"
  readonly property color bg: Quickshell.env("GLANCE_BG") || "#101315"
  readonly property color alert: Quickshell.env("GLANCE_ALERT") || "#a55555"
  readonly property string out: Quickshell.env("GLANCE_OUT") || "/tmp"
  FloatingWindow {
    id: win; implicitWidth: 400; implicitHeight: 120; visible: true; color: shell.bg
    Column {
      id: col
      x: 8; y: 8; spacing: 8
      Repeater {
        model: [ { p: shell.p, e: shell.e, tag: "real" }, { p: 0.20, e: 0.50, tag: "underpace" } ]
        Row {
          id: strip
          required property var modelData
          objectName: "strip-" + modelData.tag
          spacing: Style.space(1)
          Repeater {
            model: [4, 5, 6, 7, 8, 9]
            GlanceVariant {
              required property int modelData
              objectName: "v" + modelData
              variant: modelData
              percent: strip.modelData.p
              elapsed: strip.modelData.e
              daysLeft: shell.d
              resetText: shell.r
              iconSource: Qt.resolvedUrl("assets/grok-bot.svg")
              // Theme colours when loaded, stock defaults otherwise.
              foreground: shell.fg
              alertColor: shell.alert
            }
          }
        }
      }
    }
    Timer { id: quitLater; interval: 3000; onTriggered: Qt.quit() }
    Timer {
      interval: 2500; running: true
      onTriggered: {
        var strips = col.children.filter(function(c) { return c.objectName && c.objectName.indexOf("strip-") === 0 })
        var jobs = 0
        strips.forEach(function(s) {
          var kids = s.children.filter(function(c) { return c.objectName && c.objectName[0] === "v" })
          kids.forEach(function(k) {
            jobs++
            console.log("GLANCE icon=" + k.iconStatus + " iconBox=" + k.iconX + "," + k.iconY + "," + k.iconSize + " " + s.objectName + " " + k.objectName + " w=" + k.width + " h=" + k.height + " overPace=" + k.overPace + " ring=" + k.ringColor)
            k.grabToImage(function(res) {
              res.saveToFile(shell.out + "/grok-glance-" + s.objectName.slice(6) + "-" + k.objectName + ".png"); if (--jobs === 0) quitLater.start()
            }, Qt.size(k.width * 4, k.height * 4))
          })
        })
        win.contentItem.grabToImage(function(res) { console.log("GLANCE all saved=" + res.saveToFile(shell.out + "/grok-glance-window.png")) })
      }
    }
  }
}
