import QtQuick
import Quickshell.Wayland

// Pure view: every workspace with windows as a tile in ONE horizontal row
// (GNOME-style), all of them fully visible; tiles shrink as more exist.
// Windows sit where they really are, as live previews.
// progress 0 = the anchor tile fills the screen exactly like the desktop,
// 1 = the overview. The owner drives progress (finger-synced or animated).
// No Hyprland access here, so tests can render it with fake data.
Item {
  id: view

  // [{ id, name, windows: [{ address, cls, title, icon, x, y, w, h, floating, focus }] }]
  property var workspaces: []
  property var monitor: ({ x: 0, y: 0, w: 1920, h: 1080 })   // logical px
  property int activeId: -1
  property int selectedIndex: 0
  property int anchorIndex: 0       // tile that zooms to full screen at progress 0
  property real progress: 1
  property bool thumbnails: true
  property bool live: true
  property var toplevelFor: function(address) { return null }

  property color background: "#101315"
  property color foreground: "#cacccc"
  property color accent: "#cacccc"
  property color scrim: Qt.rgba(0, 0, 0, 0.5)
  property string fontFamily: "sans-serif"
  property int radius: 0

  signal focusWindow(string address, int tileIndex)
  signal switchWorkspace(int id, int tileIndex)
  signal moveWindow(string address, int workspaceId)
  signal dismissRequested()

  readonly property real p: Math.max(0, Math.min(1, progress))
  readonly property int count: Math.max(1, workspaces.length)
  readonly property int gap: Math.round(Math.min(width, height) * 0.025)
  readonly property int labelH: 28
  readonly property real aspect: monitor.w > 0 && monitor.h > 0 ? monitor.w / monitor.h : 16 / 9

  // One row; the biggest tile that lets every workspace fit, capped like GNOME's
  // single-workspace view (about 60 % of the screen height).
  readonly property real tileW: Math.max(24, Math.min((width - gap * (count + 1)) / count,
                                                      (height - 2 * gap - labelH) * 0.62 * aspect))
  readonly property real tileH: tileW / aspect
  readonly property real rowW: count * tileW + (count - 1) * gap
  readonly property real rowX: (width - rowW) / 2
  readonly property real rowY: (height - tileH - labelH) / 2

  function tileX(i) { return rowX + i * (tileW + gap) }

  // Zoom: at p = 0 the anchor tile covers the whole view, at p = 1 identity.
  readonly property real zoomFrom: width > 0 ? width / tileW : 1
  readonly property real zoom: zoomFrom + (1 - zoomFrom) * p
  readonly property real anchorX: tileX(Math.max(0, Math.min(workspaces.length - 1, anchorIndex)))

  Rectangle { anchors.fill: parent; color: view.scrim; opacity: view.p }
  MouseArea { anchors.fill: parent; onClicked: view.dismissRequested() }

  Item {
    id: row
    width: view.width; height: view.height
    transform: [
      Scale { origin.x: 0; origin.y: 0; xScale: view.zoom; yScale: view.zoom },
      Translate {
        x: view.anchorX * view.p - view.anchorX * view.zoom
        y: view.rowY * view.p - view.rowY * view.zoom
      }
    ]

    Repeater {
      id: tiles
      model: view.workspaces
      delegate: Item {
        id: tileCol
        required property var modelData
        required property int index
        readonly property bool current: modelData.id === view.activeId
        readonly property bool selected: index === view.selectedIndex
        property bool dropHover: false
        x: view.tileX(index)
        y: view.rowY
        width: view.tileW
        height: view.tileH + view.labelH

        Rectangle {
          id: tile
          width: view.tileW
          height: view.tileH
          radius: view.radius / Math.max(1, view.zoom)
          color: Qt.rgba(0, 0, 0, 0)
          clip: true

          Rectangle {   // tile backdrop fades in so p = 0 looks like the desktop
            anchors.fill: parent
            radius: parent.radius
            color: Qt.darker(view.background, 1.3)
            opacity: view.p
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: view.selectedIndex = tileCol.index
            onClicked: view.switchWorkspace(tileCol.modelData.id, tileCol.index)
          }

          Repeater {
            model: tileCol.modelData.windows
            delegate: Item {
              id: win
              required property var modelData
              readonly property real sx: view.tileW / view.monitor.w
              readonly property real sy: view.tileH / view.monitor.h
              x: (modelData.x - view.monitor.x) * sx
              y: (modelData.y - view.monitor.y) * sy
              width: Math.max(4, modelData.w * sx)
              height: Math.max(4, modelData.h * sy)

              Rectangle {   // icon fallback until (or unless) the live capture has a frame
                anchors.fill: parent
                radius: view.radius / Math.max(1, view.zoom)
                color: Qt.lighter(view.background, 1.7)
                opacity: shot.hasContent ? 0 : view.p
                Column {
                  anchors.centerIn: parent
                  width: parent.width - 8
                  spacing: 4
                  Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: win.modelData.icon || ""
                    visible: source != ""
                    width: Math.min(48, win.width * 0.4, win.height * 0.45)
                    height: width
                    sourceSize.width: 96
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectFit
                  }
                  Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: win.modelData.title || win.modelData.cls || ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: view.foreground
                    font.family: view.fontFamily
                    font.pixelSize: 11
                    visible: win.height > 40
                  }
                }
              }

              ScreencopyView {
                id: shot
                anchors.fill: parent
                live: view.live
                captureSource: view.thumbnails ? view.toplevelFor(win.modelData.address) : null
              }

              Rectangle {   // hover outline
                anchors.fill: parent
                color: "transparent"
                radius: view.radius / Math.max(1, view.zoom)
                border.width: 2
                border.color: view.accent
                visible: hover.containsMouse && view.p > 0.98
              }

              MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                property point start
                property bool dragging: false
                onPressed: function(m) { start = Qt.point(m.x, m.y); dragging = false }
                onPositionChanged: function(m) {
                  if (!pressed) return
                  if (!dragging && Math.abs(m.x - start.x) + Math.abs(m.y - start.y) > 8) {
                    dragging = true
                    ghost.text = win.modelData.title || win.modelData.cls || ""
                    ghost.visible = true
                  }
                  if (dragging) {
                    var q = mapToItem(view, m.x, m.y)
                    ghost.x = q.x - ghost.width / 2
                    ghost.y = q.y - ghost.height / 2
                    view.markDrop(q)
                  }
                }
                onReleased: function(m) {
                  if (!dragging) return
                  var q = mapToItem(view, m.x, m.y)
                  var target = view.tileAt(q)
                  ghost.visible = false
                  view.markDrop(Qt.point(-1, -1))
                  if (target && target.id !== tileCol.modelData.id) view.moveWindow(win.modelData.address, target.id)
                  dragging = false
                }
                onClicked: if (!dragging) view.focusWindow(win.modelData.address, tileCol.index)
              }
            }
          }

          Rectangle {   // tile outline, drawn over the previews
            anchors.fill: parent
            color: "transparent"
            radius: parent.radius
            opacity: view.p
            border.width: tileCol.current || tileCol.selected || tileCol.dropHover ? 3 : 1
            border.color: tileCol.current || tileCol.dropHover ? view.accent
                         : (tileCol.selected ? view.foreground : Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.25))
          }
        }

        Text {
          y: view.tileH + 6
          width: view.tileW
          horizontalAlignment: Text.AlignHCenter
          text: tileCol.modelData.name
          textFormat: Text.PlainText
          color: tileCol.current ? view.accent : view.foreground
          opacity: view.p
          font.family: view.fontFamily
          font.pixelSize: 14
          font.bold: tileCol.current
        }
      }
    }
  }

  // Tile under a point in view coordinates (only meaningful at p = 1).
  function tileAt(q) {
    for (var i = 0; i < tiles.count; i++) {
      var it = tiles.itemAt(i)
      if (!it) continue
      var r = view.mapToItem(it, q.x, q.y)
      if (r.x >= 0 && r.y >= 0 && r.x <= view.tileW && r.y <= view.tileH) return it.modelData
    }
    return null
  }
  function markDrop(q) {
    for (var i = 0; i < tiles.count; i++) {
      var it = tiles.itemAt(i)
      if (!it) continue
      var r = view.mapToItem(it, q.x, q.y)
      it.dropHover = r.x >= 0 && r.y >= 0 && r.x <= view.tileW && r.y <= view.tileH
    }
  }
  // Where tile i is drawn right now (view coordinates), for tests.
  function tileRect(i) {
    var it = tiles.itemAt(i)
    if (!it) return null
    var a = it.mapToItem(view, 0, 0), b = it.mapToItem(view, view.tileW, view.tileH)
    return { x: a.x, y: a.y, w: b.x - a.x, h: b.y - a.y }
  }

  Rectangle {
    id: ghost
    property alias text: ghostText.text
    visible: false
    width: 180; height: 34
    radius: view.radius
    color: view.background
    border.color: view.accent
    border.width: 2
    opacity: 0.9
    Text {
      id: ghostText
      anchors.fill: parent; anchors.margins: 6
      textFormat: Text.PlainText
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
      color: view.foreground
      font.family: view.fontFamily
      font.pixelSize: 12
    }
  }
}
