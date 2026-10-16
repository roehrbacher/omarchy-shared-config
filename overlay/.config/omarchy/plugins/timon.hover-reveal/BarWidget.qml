import QtQuick

// Hover reveal for bar widgets.
//
// Put { "id": "timon.hover-reveal" } once anywhere in bar.layout. It draws
// nothing and takes no space. Every other bar entry that carries
// "revealOnHover": true then stays invisible in its normal place (opacity 0,
// its space kept, nothing around it moves) and fades in exactly like the stock
// omarchy.indicators next to the clock:
//
//   trigger  the stock bar's own peek state (bar.centerSectionRevealHeld and
//            bar.centerHoverRevealSuppressed, the same properties Indicators.qml
//            reads): it opens when the pointer enters the center section (the
//            bar outside the left/right widget groups), holds while the pointer
//            is anywhere on the bar, and closes 120 ms after it leaves the bar
//            (the bar's centerSectionRevealTimer)
//   fade     140 ms, Easing.OutCubic, both ways (WidgetButton's opacity
//            Behavior that the indicators use)
//
// Bars without that state (an old or replacement bar) fall back to plain
// whole-bar hover with a 450 ms hold.
//
//
//   { "id": "timon.media", "revealOnHover": true }
//
// Add "revealCollapse": true to an entry to instead fold it to zero width
// while hidden (no gap) and let it slide in.
//
// A revealed widget stays visible while its own popup is open (Panel.opened,
// a popupOpen property, or the bar's active popout), so a popup opened from
// the bar, a hotkey or IPC stays usable. The widget itself is untouched and
// stays loaded the whole time, so its IPC handlers, timers and keybinds keep
// working.
//
// How: the stock bar has no per-entry reveal option, so this helper finds
// the bar's module slots in its own bar window (one helper per monitor) and
// only replaces the opacity (and, with revealCollapse, size) bindings of the
// marked slots. Nothing else of the stock bar is changed. If a future Omarchy
// renames those slot properties the helper finds no slots and every widget
// simply stays visible.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool vertical: !!bar && bar.vertical === true
  readonly property int barSize: bar && bar.barSize > 0 ? bar.barSize : 26
  // Stock WidgetButton fade: Behavior on opacity { 140 ms, OutCubic }.
  readonly property int revealMs: setting("revealMs", 140)
  readonly property int hideMs: setting("hideMs", 140)
  readonly property int hideDelayMs: setting("hideDelayMs", 450)

  // Same reveal condition as omarchy.indicators' revealInactiveIndicators.
  readonly property bool stockTrigger: !!bar && bar.centerSectionRevealHeld !== undefined
  readonly property bool stockRevealed: stockTrigger && bar.centerSectionRevealHeld === true
    && bar.centerHoverRevealSuppressed !== true

  property bool barHovered: false
  property bool holding: false
  readonly property bool revealed: stockTrigger ? stockRevealed : (barHovered || holding)

  property var hoverHandler: null
  property var hoverParent: null
  property var installedSlots: []

  visible: false
  implicitWidth: 0
  implicitHeight: 0

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null || isNaN(Number(value)) ? fallback : Number(value)
  }

  function setBarHovered(hovered) {
    barHovered = hovered
    if (hovered) {
      hideTimer.stop()
      holding = true
      scan()
    } else {
      hideTimer.restart()
    }
  }

  function topItem() {
    var item = root
    while (item && item.parent) item = item.parent
    return item === root ? null : item
  }

  function ensureHover(top) {
    if (hoverHandler && hoverParent === top) return
    if (hoverHandler) hoverHandler.destroy()
    hoverHandler = hoverComponent.createObject(top)
    if (hoverHandler) hoverHandler.parent = top
    hoverParent = top
  }

  function isSlot(item) {
    return !!item && item !== root
      && item.moduleSettings !== undefined
      && item.activeItem !== undefined
      && item.panelOpen !== undefined
      && item.registryComponent !== undefined
  }

  function installed(slot) {
    var kids = slot.children
    for (var i = 0; i < kids.length; i++)
      if (kids[i] && kids[i].objectName === "timon.hover-reveal.holder") return true
    return false
  }

  function install(slot) {
    var holder = holderComponent.createObject(slot, { slot: slot })
    if (!holder) return
    // Same as the stock slot binding, scaled by the reveal progress.
    slot.implicitWidth = Qt.binding(function() {
      var item = slot.activeItem
      if (!item || !item.visible) return 0
      if (root.vertical) return root.barSize
      return holder.keepSpace ? item.implicitWidth : item.implicitWidth * holder.progress
    })
    slot.implicitHeight = Qt.binding(function() {
      var item = slot.activeItem
      if (!item || !item.visible) return 0
      if (!root.vertical || holder.keepSpace) return item.implicitHeight
      return item.implicitHeight * holder.progress
    })
    slot.opacity = Qt.binding(function() { return holder.progress })
    slot.clip = Qt.binding(function() { return !holder.keepSpace && holder.progress < 1 })
    installedSlots = installedSlots.concat([{ slot: slot, holder: holder }])
  }

  // Hand the slots back to plain stock-style bindings when this helper goes
  // away (plugin reload or removal) so nothing stays folded without it.
  function restore(slot, vertical, barSize) {
    slot.implicitWidth = Qt.binding(function() {
      var item = slot.activeItem
      return item && item.visible ? (vertical ? barSize : item.implicitWidth) : 0
    })
    slot.implicitHeight = Qt.binding(function() {
      var item = slot.activeItem
      return item && item.visible ? item.implicitHeight : 0
    })
    slot.opacity = 1
    slot.clip = false
  }

  function uninstallAll() {
    var vertical = root.vertical
    var barSize = root.barSize
    for (var i = 0; i < installedSlots.length; i++) {
      var rec = installedSlots[i]
      try {
        if (rec.slot && rec.slot.moduleSettings !== undefined) restore(rec.slot, vertical, barSize)
        if (rec.holder) rec.holder.destroy()
      } catch (e) {
      }
    }
    installedSlots = []
  }

  function scan() {
    var top = topItem()
    if (!top) return
    ensureHover(top)
    var stack = [top]
    while (stack.length > 0) {
      var item = stack.pop()
      var kids = item.children
      for (var i = 0; i < kids.length; i++) {
        var child = kids[i]
        if (!child || child === root) continue
        if (isSlot(child)) {
          var s = child.moduleSettings
          if (s && s.revealOnHover === true && !installed(child)) install(child)
          continue
        }
        stack.push(child)
      }
    }
  }

  Timer {
    id: hideTimer
    interval: root.hideDelayMs
    onTriggered: if (!root.barHovered) root.holding = false
  }

  // Slots are rebuilt whenever shell.json changes; pick new ones up.
  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.scan()
  }

  Component.onCompleted: Qt.callLater(root.scan)
  Component.onDestruction: {
    uninstallAll()
    if (hoverHandler) hoverHandler.destroy()
  }

  Component {
    id: hoverComponent
    HoverHandler {
      onHoveredChanged: root.setBarHovered(hovered)
    }
  }

  Component {
    id: holderComponent

    Item {
      id: holder

      property var slot: null
      readonly property var item: slot ? slot.activeItem : null
      readonly property bool keep: !!slot && (slot.panelOpen === true
        || slot.dragSource === true
        || (!!item && (item.opened === true || item.popupOpen === true)))
      readonly property bool shown: root.revealed || keep
      readonly property bool keepSpace: !slot || !slot.moduleSettings
        || slot.moduleSettings.revealCollapse !== true
      property real progress: shown ? 1 : 0

      objectName: "timon.hover-reveal.holder"
      visible: false
      width: 0
      height: 0

      Behavior on progress {
        NumberAnimation {
          duration: holder.shown ? root.revealMs : root.hideMs
          easing.type: Easing.OutCubic
        }
      }
    }
  }
}
