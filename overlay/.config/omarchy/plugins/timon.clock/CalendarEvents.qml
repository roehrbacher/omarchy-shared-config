// Proton Calendar events for the month grid. Data comes from
// ~/.cache/omarchy/proton-calendar/events.json, written every 30 min by
// omarchy-proton-calendar-sync (systemd user timer). Nothing personal lives
// in this plugin; the share links are local files in
// ~/.config/omarchy/proton-calendar/<name>.url.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

Item {
  id: root
  visible: false

  readonly property string cachePath: Quickshell.env("HOME") + "/.cache/omarchy/proton-calendar/events.json"
  readonly property string colorsPath: Commons.Color.currentThemePath + "/colors.toml"
  property var days: ({})
  property var calendars: []
  property string updated: ""
  property var palette: ({})
  property int revision: 0

  // Theme palette: private uses the accent (color4), work the theme's green
  // (color2), a third calendar magenta (color5).
  readonly property var slots: ({ private: "accent", work: "color2" })
  readonly property var extraSlots: ["color5", "color3", "color6"]

  function colorFor(name) {
    var slot = slots[name]
    if (!slot) {
      var i = Math.max(0, calendars.indexOf(name) - 2)
      slot = extraSlots[i % extraSlots.length]
    }
    if (slot === "accent") return Commons.Color.accent
    var c = palette[slot]
    return c ? c : (name === "work" ? Commons.Color.urgent : Commons.Color.accent)
  }

  function labelFor(name) {
    return name.charAt(0).toUpperCase() + name.slice(1)
  }

  function eventsFor(key) {
    revision
    return days[key] || []
  }

  // Distinct calendars on a day, in calendar order, for the dots.
  function calendarsOn(key) {
    var list = eventsFor(key), seen = []
    for (var i = 0; i < list.length; i++)
      if (seen.indexOf(list[i].calendar) < 0) seen.push(list[i].calendar)
    seen.sort(function(a, b) { return root.calendars.indexOf(a) - root.calendars.indexOf(b) })
    return seen
  }

  // Proton Calendar web app, opened on the given day.
  function openDay(year, month, day) {
    var url = "https://calendar.proton.me/u/0/day/" + year + "/" + (month + 1) + "/" + day
    Quickshell.execDetached(["omarchy-launch-webapp", url])
  }

  FileView {
    path: root.cachePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        root.days = d.days || {}
        root.calendars = d.calendars || []
        root.updated = d.updated || ""
      } catch (e) { root.days = {} }
      root.revision++
    }
    onFileChanged: reload()
  }

  FileView {
    path: root.colorsPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      var p = {}, lines = text().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*([a-z0-9_]+)\s*=\s*"([^"]+)"/)
        if (m) p[m[1]] = m[2]
      }
      root.palette = p
      root.revision++
    }
    onFileChanged: reload()
  }
}
