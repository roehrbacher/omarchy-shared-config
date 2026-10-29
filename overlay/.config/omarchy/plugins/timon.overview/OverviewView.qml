import QtQuick
import Quickshell.Wayland

// Pure view: workspaces as scaled tiles, windows laid out by real geometry.
// No Hyprland access here, so tests can render it with fake data.
Item {
  id: view

  // [{ id, name, windows: [{ address, cls, title, icon, x, y, w, h, floating, focus }] }]
  property var workspaces: []
  property var monitor: ({ x: 0, y: 0, w: 1920, h: 1080 })   // logical px
  property int activeId: -1
  property int selectedIndex: 0
  property bool thumbnails: true
  property var toplevelFor: function(address) { return null }

  property color background: "#101315"
  property color foreground: "#cacccc"
  property color accent: "#cacccc"
  property color scrim: Qt.rgba(0, 0, 0, 0.5)
  property string fontFamily: "sans-serif"
  property int radius: 0

  signal focusWindow(string address)
  signal switchWorkspace(int id)
  signal moveWindow(string address, int workspaceId)
  signal dismissRequested()

  readonly property int gap: Math.round(Math.min(width, height) * 0.03)
  readonly property int labelH: 26
  readonly property real aspect: monitor.w > 0 && monitor.h > 0 ? monitor.w / monitor.h : 16 / 9

  // Pick the column count that gives the biggest tiles.
  readonly property var grid: {
    var n = Math.max(1, workspaces.length), best = { cols: 1, w: 0 }
    for (var cols = 1; cols <= n; cols++) {
      var rows = Math.ceil(n / cols)
      var w = Math.min((width - gap * (cols + 1)) / cols,
                       ((height - gap * (rows + 1)) / rows - labelH) * aspect)
      if (w > best.w) best = { cols: cols, w: w }
    }
    best.w = Math.min(best.w, width * 0.42)
    return best
  }
  readonly property real tileW: Math.max(40, grid.w)
  readonly property real tileH: tileW / aspect

  Rectangle { anchors.fill: parent; color: view.scrim }
  MouseArea { anchors.fill: parent; onClicked: view.dismissRequested() }

  Flow {
    id: flow
    anchors.centerIn: parent
    width: Math.min(parent.width, view.grid.cols * view.tileW + (view.grid.cols - 1) * view.gap)
    spacing: view.gap

    Repeater {
      id: tiles
      model: view.workspaces
      delegate: Column {
        id: tileCol
        required property var modelData
        required property int index
        readonly property bool current: modelData.id === view.activeId
        readonly property bool selected: index === view.selectedIndex
        property bool dropHover: false
        spacing: 6
        width: view.tileW

        Rectangle {
          id: tile
          width: view.tileW
          height: view.tileH
          radius: view.radius
          color: Qt.darker(view.background, 1.3)
          clip: true
          border.width: tileCol.current || tileCol.selected || tileCol.dropHover ? 3 : 1
          border.color: tileCol.current || tileCol.dropHover ? view.accent
                       : (tileCol.selected ? view.foreground : Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.25))

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: view.selectedIndex = tileCol.index
            onClicked: view.switchWorkspace(tileCol.modelData.id)
          }

          Repeater {
            model: tileCol.modelData.windows
            delegate: Rectangle {
              id: win
              required property var modelData
              readonly property real sx: view.tileW / view.monitor.w
              readonly property real sy: view.tileH / view.monitor.h
              x: (modelData.x - view.monitor.x) * sx
              y: (modelData.y - view.monitor.y) * sy
              width: Math.max(8, modelData.w * sx)
              height: Math.max(8, modelData.h * sy)
              radius: view.radius
              color: Qt.lighter(view.background, 1.7)
              border.width: hover.containsMouse ? 2 : 1
              border.color: hover.containsMouse ? view.accent : Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.55)
              clip: true

              Column {
                anchors.centerIn: parent
                width: parent.width - 8
                spacing: 4
                visible: !shot.hasContent
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

              ScreencopyView {
                id: shot
                anchors.fill: parent
                anchors.margins: 1
                live: false
                captureSource: view.thumbnails ? view.toplevelFor(win.modelData.address) : null
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
                    var p = mapToItem(view, m.x, m.y)
                    ghost.x = p.x - ghost.width / 2
                    ghost.y = p.y - ghost.height / 2
                    view.markDrop(p)
                  }
                }
                onReleased: function(m) {
                  if (!dragging) return
                  var p = mapToItem(view, m.x, m.y)
                  var target = view.tileAt(p)
                  ghost.visible = false
                  view.markDrop(Qt.point(-1, -1))
                  if (target && target.id !== tileCol.modelData.id) view.moveWindow(win.modelData.address, target.id)
                  dragging = false
                }
                onClicked: if (!dragging) view.focusWindow(win.modelData.address)
              }
            }
          }
        }

        Text {
          width: view.tileW
          horizontalAlignment: Text.AlignHCenter
          text: tileCol.modelData.name
          textFormat: Text.PlainText
          color: tileCol.current ? view.accent : view.foreground
          font.family: view.fontFamily
          font.pixelSize: 14
          font.bold: tileCol.current
        }
      }
    }
  }

  function tileAt(p) {
    for (var i = 0; i < tiles.count; i++) {
      var it = tiles.itemAt(i)
      if (!it) continue
      var q = view.mapToItem(it, p.x, p.y)
      if (q.x >= 0 && q.y >= 0 && q.x <= it.width && q.y <= it.height) return it.modelData
    }
    return null
  }
  function markDrop(p) {
    for (var i = 0; i < tiles.count; i++) {
      var it = tiles.itemAt(i)
      if (!it) continue
      var q = view.mapToItem(it, p.x, p.y)
      it.dropHover = q.x >= 0 && q.y >= 0 && q.x <= it.width && q.y <= it.height
    }
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
