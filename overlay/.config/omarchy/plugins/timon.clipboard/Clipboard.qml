// timon.clipboard: clipboard history popup with the UX of GNOME Clipboard
// History (pinned items, incognito mode, regex search, Alt+N), built on
// Omarchy's stock clipboard overlay (shell/plugins/clipboard/Clipboard.qml).
//
// History lives only in ~/.local/share/timon.clipboard/ (folder 0700, files
// 0600). Clipboard contents are never logged and never leave this machine.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "ClipboardHistory.js" as ClipboardHistory
import "Bridge.js" as Bridge

Item {
  id: root

  // ---- settings (edit here) --------------------------------------------
  // Unpinned entries kept; pinned entries never count against the limit.
  property int historyLimit: 500
  // Rows rendered per search (the rest is a search away).
  property int displayLimit: 200

  // ---- state ------------------------------------------------------------
  property bool opened: false
  property bool ready: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool clearConfirmOpen: false
  // Shortcuts & settings view (gear icon in the footer, or F1 / Ctrl+/).
  property bool infoOpen: false
  property int infoIndex: 0
  readonly property var infoActions: ["incognito", "clear", "back", "send"]
  // Flux details for the settings view (from `flux-cli status --json`).
  property string phoneName: ""
  property int lastSync: 0
  property int nowSec: Math.floor(Date.now() / 1000)
  // Header phone icon: "online", "paused" (incognito) or "" (hidden).
  // flux-pause.sh's last answer: absent, running, paused or off.
  property string fluxState: ""
  // Footer phone button: "online", "nophone", "paused", "off" or "" (hidden).
  readonly property string phoneIcon: ClipboardHistory.phoneIconState(root.fluxState, root.phoneOnline)
  readonly property string fluxStatusText: !root.fluxPresent ? "not installed"
    : (root.fluxPaused ? "paused (incognito)"
    : (root.phoneOnline ? "running · phone connected" : "running · no phone connected"))
  property bool privateMode: false
  // Flux (fluxd) clipboard sync: paused by flux-pause.sh while private mode is on.
  property bool fluxPresent: false
  property bool fluxPaused: false
  property bool fluxResync: false
  property bool hasPinned: false
  property var history: []
  // Ctrl/Alt+N: display index waiting for the modifier release (-1 = none).
  property int pendingPasteIndex: -1
  // Keyboard focus on a row action of the selected row (-1 = the row itself).
  property int actionFocus: -1
  readonly property var selectedActions: root.rowActions(root.selectedIndex, root.armedDeleteIndex, root.phoneOnline, displayModel.count)
  readonly property string focusedAction: root.actionFocus >= 0 && root.actionFocus < selectedActions.length ? selectedActions[root.actionFocus] : ""
  // Pinned entry (history index) armed by a first Del (-1 = none).
  property int armedDeleteIndex: -1
  // Flux: a paired phone is online (checked when the popup opens).
  property bool phoneOnline: false
  // Texts captured a moment ago, waiting for the Flux "from phone" check.
  property var originQueue: []

  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")
  readonly property string dataDir: dataHome + "/timon.clipboard"
  readonly property string historyPath: dataDir + "/history.json"
  readonly property string statePath: dataDir + "/state.json"
  readonly property string captureScript: pluginDir + "/capture.sh"
  readonly property string helper: pluginDir + "/clipboard.sh"
  readonly property string fluxScript: pluginDir + "/flux-pause.sh"

  // Same [menu] surface tokens as the stock clipboard, so every theme styles it.
  // Popup surface tokens, same as the stock Wi-Fi popup (KeyboardPanel).
  property color background: Color.popups.background
  property color foreground: Color.popups.text
  property color border: Color.popups.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Style.selectedFillFor(foreground, Color.accent)
  property color selectedText: foreground
  property color accent: Color.accent
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int footerRowHeight: Math.max(Style.space(26), Style.font.body + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  // Small extra gap between the list and the footer.
  property int footerGap: Style.space(4)
  // Scales with the screen's logical height: unchanged from 1080 px up,
  // 20% smaller on a small laptop screen (ClipboardHistory.popupScale).
  readonly property real popupScale: ClipboardHistory.popupScale(panel.screenH)
  // List only (no preview column): half the old 875 px width.
  property int cardWidth: panel.fittedContentWidth(Math.round(Style.space(462) * popupScale))
  property int cardHeight: panel.cappedContentHeight(Math.round(Style.space(630) * popupScale))
  // Bar icon the popup hangs from (set by BarWidget.qml through Bridge.js).
  property Item anchorButton: null
  property QtObject anchorBar: null
  property Item anchorWidget: null
  function setAnchor(button, bar, widget) { root.anchorButton = button; root.anchorBar = bar; root.anchorWidget = widget || null }
  // Secondary text: same size and contrast as the stock Wi-Fi panel's
  // smallest text (foreground darkened 1.4x, no opacity); hints use the count size (Style.font.body).
  readonly property color dimText: Qt.darker(foreground, 1.4)
  readonly property color urgent: Color.urgent
  // Compact rows like the Wi-Fi list: one line plus a small padding.
  property int rowHeight: Math.max(Style.space(30), Style.font.title + Style.spacing.rowPaddingX + Style.space(6))

  // ---- open / close (shell host API) ------------------------------------
  function open(payloadJson) {
    root.opened = true
    root.infoOpen = false
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
    if (root.fluxPresent && !root.fluxPaused && !statusProc.running) statusProc.running = true
    else if (!root.fluxPresent || root.fluxPaused) root.phoneOnline = false
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function openInfo(section) {
    root.disarmDelete()
    root.nowSec = Math.floor(Date.now() / 1000)
    root.infoIndex = section === "flux" ? root.infoActions.indexOf("send") : 0
    root.infoOpen = true
    if (root.fluxPresent && !root.fluxPaused && !statusProc.running) statusProc.running = true
    if (section === "flux") Qt.callLater(function() {
      infoFlick.contentY = Math.max(0, Math.min(fluxSection.y, infoFlick.contentHeight - infoFlick.height))
    })
    else infoFlick.contentY = 0
  }

  // Footer phone button: open Flux's own window (flux-cli open: its shell
  // plugin, else flux-gui) and close the popup; without flux-cli, the Flux
  // section of the settings view.
  function openFlux() {
    if (root.fluxPresent) {
      root.close()
      Quickshell.execDetached(["flux-cli", "open"])
    } else root.openInfo("flux")
  }

  // Send what is on the clipboard now to the phone (flux-cli clip).
  function sendCurrentClipboard() {
    if (!root.phoneOnline || root.fluxPaused) return
    Quickshell.execDetached(["flux-cli", "clip"])
    root.lastSync = Math.floor(Date.now() / 1000)
    root.nowSec = root.lastSync
  }

  function closeInfo() {
    root.infoOpen = false
    root.disarmPointer()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function runInfoAction(name) {
    if (name === "incognito") root.setPrivate(!root.privateMode, false)
    else if (name === "clear") { root.infoOpen = false; root.requestClearHistory() }
    else if (name === "send") root.sendCurrentClipboard()
    else root.closeInfo()
  }

  // Keys while the shortcuts & settings view is shown: ↑↓/Tab pick a
  // setting, Enter/Space toggle it, PgUp/PgDn scroll, Esc goes back.
  function handleInfoKey(event) {
    var k = event.key
    var n = root.infoActions.length
    if ((event.modifiers & Qt.ControlModifier) && k === Qt.Key_S) root.sendCurrentClipboard()
    else if (k === Qt.Key_Escape || k === Qt.Key_F1 || ((event.modifiers & Qt.ControlModifier) && k === Qt.Key_Slash)) root.closeInfo()
    else if (k === Qt.Key_Down || k === Qt.Key_Tab) root.infoIndex = (root.infoIndex + 1) % n
    else if (k === Qt.Key_Up || k === Qt.Key_Backtab) root.infoIndex = (root.infoIndex + n - 1) % n
    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.runInfoAction(root.infoActions[root.infoIndex])
    else if (k === Qt.Key_PageDown) infoFlick.contentY = Math.min(Math.max(0, infoFlick.contentHeight - infoFlick.height), infoFlick.contentY + infoFlick.height * 0.8)
    else if (k === Qt.Key_PageUp) infoFlick.contentY = Math.max(0, infoFlick.contentY - infoFlick.height * 0.8)
    event.accepted = true
  }

  function close() {
    root.infoOpen = false
    root.disarmDelete()
    root.pendingPasteIndex = -1
    root.cancelClearHistory()
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  // ---- IPC: omarchy-shell shell call timon.clipboard <method> x ----------
  function togglePrivate(arg) {
    root.setPrivate(!root.privateMode, !root.opened)
    return root.privateMode ? "private" : "recording"
  }

  function setPrivateMode(arg) {
    root.setPrivate(String(arg) === "true" || String(arg) === "on", !root.opened)
    return root.privateMode ? "private" : "recording"
  }

  // Same as togglePrivate / setPrivateMode (the UI calls it "Incognito").
  function toggleIncognito(arg) { return root.togglePrivate(arg) }
  function setIncognito(arg) { return root.setPrivateMode(arg) }

  function status(arg) {
    return JSON.stringify({ private: root.privateMode, incognito: root.privateMode, fluxPaused: root.fluxPaused, open: root.opened, entries: root.history.length, shown: displayModel.count })
  }

  // ---- incognito (private) mode -------------------------------------------
  function setPrivate(value, notify) {
    var fluxWasPaused = root.fluxPaused
    root.privateMode = value
    stateFile.setText(JSON.stringify({ private: value }) + "\n")
    root.syncFlux()
    if (notify) {
      Quickshell.execDetached(["notify-send", "-a", "Clipboard", "-t", "2500",
        value ? "Clipboard incognito on" : "Clipboard incognito off",
        value ? "New copies are not saved." + (root.fluxPresent ? " Flux sync paused." : "")
              : "Copies are saved to history again." + (fluxWasPaused ? " Flux sync resumed." : "")])
    }
  }

  function loadState(raw) {
    try { root.privateMode = JSON.parse(String(raw || "{}")).private === true }
    catch (e) { root.privateMode = false }
    // Also runs at shell start: resumes Flux if private mode ended while the
    // shell was down, pauses it again if private mode is still on.
    root.syncFlux()
  }

  // Make Flux match private mode (pause or resume fluxd via flux-pause.sh).
  function syncFlux() {
    if (fluxProc.running) root.fluxResync = true
    else fluxProc.running = true
  }

  // ---- history ----------------------------------------------------------
  function loadHistory(raw) {
    root.history = ClipboardHistory.pruneToLimit(ClipboardHistory.parseHistory(raw), root.historyLimit)
    if (root.opened) root.rebuildDisplay()
  }

  function saveHistory() {
    historyFile.setText(JSON.stringify(root.history) + "\n")
    pruneTimer.restart()
  }

  function addClipboardJson(line) {
    if (root.privateMode) return
    var entry = ClipboardHistory.parseEntryJson(line)
    if (!entry) return
    root.history = ClipboardHistory.addEntry(root.history, entry, root.historyLimit)
    root.saveHistory()
    if (root.opened) root.rebuildDisplay()
    if (entry.type === "text" && root.fluxPresent && !root.fluxPaused) {
      root.originQueue = root.originQueue.concat([entry.text]).slice(-5)
      originTimer.restart()
    }
  }

  // Flux records a copy from the phone (dir "in") before it puts it on the
  // clipboard, so `flux-cli status --json` read just after the capture tells
  // whether the new text came from the phone. Read over stdout only.
  function applyFluxStatus(raw) {
    var st = null
    try { st = JSON.parse(String(raw || "")) } catch (e) { st = null }
    if (!st) return
    root.phoneOnline = ClipboardHistory.fluxPhoneOnline(st)
    root.phoneName = ClipboardHistory.fluxPhoneName(st)
    root.lastSync = Math.max(root.lastSync, ClipboardHistory.fluxLastSync(st))
    var queue = root.originQueue
    root.originQueue = []
    var now = Math.floor(Date.now() / 1000)
    var changed = false
    for (var i = 0; i < queue.length; i++) {
      if (ClipboardHistory.fluxOrigin(st, queue[i], now) === "phone") {
        root.history = ClipboardHistory.setOrigin(root.history, queue[i], "phone")
        changed = true
      }
    }
    if (changed) {
      root.saveHistory()
      if (root.opened) root.rebuildDisplay()
    }
  }

  // ---- delete confirmation for pinned entries ------------------------------
  function disarmDelete() {
    if (root.armedDeleteIndex !== -1) root.armedDeleteIndex = -1
    armTimer.stop()
  }

  // First Del on a pinned row arms it (red, "Press Del again to delete"),
  // a second Del within 3 s deletes it. Unpinned rows go at once.
  function requestDelete(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    var armed = root.armedDeleteIndex === row.historyIndex
    if (ClipboardHistory.deleteAction(row.pinned, armed) === "arm") {
      root.selectAbsolute(index)
      root.armedDeleteIndex = row.historyIndex
      armTimer.restart()
      return
    }
    root.disarmDelete()
    root.removeDisplayIndex(index)
  }

  function requestClearHistory() {
    if (root.history.length === 0) return
    clearConfirm.selectedIndex = 1
    root.clearConfirmOpen = true
  }

  function cancelClearHistory() {
    root.clearConfirmOpen = false
    root.disarmPointer()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function confirmClearHistory() {
    var currentWasUnpinned = root.history.length > 0 && !root.history[0].pinned
    root.history = ClipboardHistory.clearHistory(root.history)
    root.saveHistory()
    if (currentWasUnpinned && !root.privateMode) Quickshell.execDetached([root.helper, "clear"])
    root.selectedIndex = 0
    root.cursorActive = false
    root.disarmPointer()
    root.clearConfirmOpen = false
    root.rebuildDisplay()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function removeDisplayIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    // Only the history changes; the system clipboard is left as it is.
    root.history = ClipboardHistory.removeEntryAt(root.history, row.historyIndex)
    root.saveHistory()

    if (displayModel.count <= 1) {
      root.selectedIndex = 0
      root.cursorActive = false
    } else if (root.selectedIndex >= displayModel.count - 1) {
      root.selectedIndex = displayModel.count - 2
    }
    root.disarmPointer()
    root.rebuildDisplay()
  }

  function togglePinDisplayIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    var historyIndex = row.historyIndex
    root.history = ClipboardHistory.togglePinAt(root.history, historyIndex)
    root.saveHistory()
    root.rebuildDisplay()
    // Keep the cursor on the entry that just moved between sections.
    for (var i = 0; i < displayModel.count; i++) {
      if (displayModel.get(i).historyIndex === historyIndex) {
        root.selectAbsolute(i)
        break
      }
    }
  }

  function rebuildDisplay() {
    var rows = ClipboardHistory.displayRows(root.history, root.filterText, root.displayLimit)
    var pinnedCount = 0
    for (var p = 0; p < rows.length; p++) if (rows[p].pinned) pinnedCount++
    root.hasPinned = pinnedCount > 0

    displayModel.clear()
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      displayModel.append({
        entryType: row.entryType,
        fullText: row.fullText,
        previewText: row.previewText,
        previewImage: row.previewImage ? Util.fileUrl(row.previewImage) : "",
        path: row.path,
        mime: row.mime,
        pinned: row.pinned,
        slot: row.slot,
        sectionName: row.pinned ? "Pinned" : (pinnedCount > 0 ? "History" : ""),
        fromPhone: row.fromPhone === true,
        historyIndex: row.index
      })
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  // ---- cursor -----------------------------------------------------------
  function select(delta) {
    root.disarmDelete()
    if (displayModel.count === 0) return
    root.disarmPointer()
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectAbsolute(index) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    root.cursorActive = true
    root.selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    if (root.armedDeleteIndex !== -1 && displayModel.get(root.selectedIndex).historyIndex !== root.armedDeleteIndex) root.disarmDelete()
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  // Alt+N: Nth row from the top (pinned first). Pastes like Enter, but only
  // once Alt is released (or after 1 s), so the paste key is not sent while
  // Alt is still held down.
  function activateSlot(slot) {
    var rows = []
    for (var i = 0; i < displayModel.count; i++) rows.push({ slot: displayModel.get(i).slot })
    var index = ClipboardHistory.slotRowIndex(rows, slot)
    if (index < 0) return
    root.selectAbsolute(index)
    root.pendingPasteIndex = index
    pasteTimer.restart()
  }

  function firePendingPaste() {
    var index = root.pendingPasteIndex
    root.pendingPasteIndex = -1
    pasteTimer.stop()
    if (index >= 0) root.activateIndex(index)
  }

  function handleSearchKeyRelease(event) {
    if (root.pendingPasteIndex >= 0 && ClipboardHistory.isModifierKey(event.key)) {
      root.firePendingPaste()
      event.accepted = true
    }
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
  }

  function disarmPointer() { pointerGate.reset() }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    if (root.armedDeleteIndex !== -1 && index !== root.selectedIndex) root.disarmDelete()
    root.cursorActive = true
    root.selectedIndex = index
  }

  // ---- actions ----------------------------------------------------------
  function runOnIndex(index, action) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.opened = false
    Quickshell.execDetached([root.helper, action, String(row.historyIndex)])
  }

  function activateIndex(index) { root.runOnIndex(index, "paste") }
  function sendIndex(index) {
    if (index < 0 || index >= displayModel.count || displayModel.get(index).entryType !== "text" || !root.phoneOnline) return
    root.runOnIndex(index, "send")
  }
  function copyIndex(index) { root.runOnIndex(index, "copy") }
  function openIndex(index) { root.runOnIndex(index, "open") }

  // Actions shown on a selected row, left to right (the extra arguments only
  // make the binding update).
  function rowActions(index, armedIndex, phone, count) {
    if (index < 0 || index >= displayModel.count) return []
    var row = displayModel.get(index)
    return ClipboardHistory.rowActionNames(row.historyIndex === root.armedDeleteIndex, root.phoneOnline, row.entryType === "text")
  }

  function runRowAction(name, index) {
    if (name === "send") root.sendIndex(index)
    else if (name === "pin") root.togglePinDisplayIndex(index)
    else if (name === "delete") root.requestDelete(index)
  }

  onSelectedIndexChanged: root.actionFocus = -1

  // ---- search field keys --------------------------------------------------
  // The search line is a real text field. Popup shortcuts are taken first
  // (ClipboardHistory.searchKeyAction); every other key edits the text, so
  // Ctrl+A, Ctrl+C/X/V, Shift+arrows and Ctrl+Backspace behave as usual.
  function handleSearchKey(event) {
    if (root.clearConfirmOpen) {
      clearConfirm.handleKey(event)
      event.accepted = true
      return
    }
    if (root.infoOpen) { root.handleInfoKey(event); return }
    if (event.key === Qt.Key_F1 || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Slash)) {
      root.openInfo()
      event.accepted = true
      return
    }

    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    var alt = (event.modifiers & Qt.AltModifier) !== 0
    var shift = (event.modifiers & Qt.ShiftModifier) !== 0

    // Left/Right walk the selected row's actions, Enter presses the focused one.
    if (root.cursorActive && displayModel.count > 0) {
      var step = ClipboardHistory.actionFocusStep(root.actionFocus, root.selectedActions.length, {
        key: event.key, ctrl: ctrl, alt: alt, shift: shift,
        atTextEnd: searchInput.cursorPosition === searchInput.text.length && searchInput.selectedText.length === 0
      })
      var pressed = step.trigger ? root.focusedAction : ""
      root.actionFocus = step.focus
      if (pressed) {
        var keepFocus = pressed === "delete" && root.armedDeleteIndex === -1
        root.runRowAction(pressed, root.selectedIndex)
        if (keepFocus && root.armedDeleteIndex !== -1) root.actionFocus = 0
      }
      if (step.consumed) { event.accepted = true; return }
    }
    var action = ClipboardHistory.searchKeyAction({
      key: event.key, ctrl: ctrl, alt: alt, shift: shift,
      hasSelection: searchInput.selectedText.length > 0
    })
    var digit = event.key >= Qt.Key_1 && event.key <= Qt.Key_9 ? event.key - Qt.Key_0 : 0
    // Any key other than Del cancels an armed pinned delete.
    if (action !== "delete" && !ClipboardHistory.isModifierKey(event.key)) root.disarmDelete()

    switch (action) {
    case "escape":
      if (root.filterText) root.setFilter("")
      else root.close()
      break
    case "slot": root.activateSlot(digit); break
    case "copySelection": root.copyText(searchInput.selectedText); break
    case "cutSelection":
      root.copyText(searchInput.selectedText)
      searchInput.remove(searchInput.selectionStart, searchInput.selectionEnd)
      break
    case "clearSearch": root.setFilter(""); break
    case "pin": if (root.cursorActive) root.togglePinDisplayIndex(root.selectedIndex); break
    case "private": root.setPrivate(!root.privateMode, false); break
    case "clear": root.requestClearHistory(); break
    case "delete": if (root.cursorActive) root.requestDelete(root.selectedIndex); break
    case "send": if (root.cursorActive) root.sendIndex(root.selectedIndex); break
    case "up": root.select(-1); break
    case "down": root.select(1); break
    case "pageUp": root.select(-6); break
    case "pageDown": root.select(6); break
    case "home": root.selectAbsolute(0); break
    case "end": root.selectAbsolute(displayModel.count - 1); break
    case "enter":
      if (root.cursorActive && alt) root.openIndex(root.selectedIndex)
      else if (root.cursorActive && shift) root.copyIndex(root.selectedIndex)
      else if (root.cursorActive) root.activateIndex(root.selectedIndex)
      else if (displayModel.count > 0) root.cursorActive = true
      break
    default:
      return
    }
    event.accepted = true
  }

  // Ctrl+C / Ctrl+X in the search field. The text goes to wl-copy over stdin
  // (never argv, never a file), so the copy outlives the popup and even a
  // shell restart, and the capture watcher records it like any other copy.
  function copyText(text) {
    if (!text) return
    copyProc.nextText = text
    if (!copyProc.running) copyProc.startCopy()
  }

  onFilterTextChanged: {
    root.actionFocus = -1
    if (searchInput.text !== root.filterText) searchInput.text = root.filterText
  }

  Process {
    id: copyProc
    property string nextText: ""
    property string sending: ""
    command: ["wl-copy"]
    function startCopy() {
      sending = nextText
      nextText = ""
      stdinEnabled = true
      running = true
    }
    onStarted: {
      write(sending)
      sending = ""
      stdinEnabled = false
    }
    onExited: if (nextText) startCopy()
  }

  // ---- startup ----------------------------------------------------------
  Component.onCompleted: {
    Bridge.setOverlay(root)
    initProc.running = true
  }
  Component.onDestruction: Bridge.clearOverlay(root)

  ListModel { id: displayModel }

  PointerMoveGate {
    id: pointerGate
    referenceItem: resultList
  }

  FileView {
    id: historyFile
    path: root.ready ? root.historyPath : ""
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
  }

  FileView {
    id: stateFile
    path: root.ready ? root.statePath : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onFileChanged: reload()
  }

  Timer {
    id: pasteTimer
    interval: 1000
    onTriggered: root.firePendingPaste()
  }

  Timer {
    id: armTimer
    interval: 3000
    onTriggered: root.armedDeleteIndex = -1
  }

  Timer {
    id: originTimer
    interval: 400
    onTriggered: if (!statusProc.running) statusProc.running = true; else restart()
  }

  Process {
    id: statusProc
    command: ["flux-cli", "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyFluxStatus(text)
    }
  }

  // Images nobody points to any more (deleted, cleared, over the limit).
  Timer {
    id: pruneTimer
    interval: 3000
    onTriggered: Quickshell.execDetached([root.helper, "prune"])
  }

  // Data dir first (0700, one-time import of the stock history), then reap
  // watchers of a previous shell, then start ours. pdeathsig makes the kernel
  // kill the watchers whenever the shell exits.
  Process {
    id: initProc
    command: ["bash", "-c", "\"$1\" init; pkill -f 'wl-paste .*--watch .*/timon\\.clipboard/capture\\.sh' || true", "init", root.helper]
    onExited: {
      root.ready = true
      currentProc.running = true
      textWatchProc.running = true
      imageWatchProc.running = true
    }
  }

  Process {
    id: fluxProc
    // Pass the wanted state instead of "sync": state.json is written
    // asynchronously, so a quick on→off could read the old value and leave
    // Flux paused.
    command: [root.fluxScript, root.privateMode ? "pause" : "resume"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var s = String(text).trim()
        root.fluxState = s
        root.fluxPresent = s !== "" && s !== "absent"
        root.fluxPaused = s === "paused"
      }
    }
    onExited: {
      if (root.fluxResync) {
        root.fluxResync = false
        Qt.callLater(function() { fluxProc.running = true })
      }
    }
  }

  Process {
    id: currentProc
    command: [root.captureScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.addClipboardJson(text)
    }
  }

  Process {
    id: textWatchProc
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch", root.captureScript, "text"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser {
      onRead: function(data) { root.addClipboardJson(data) }
    }
  }

  Process {
    id: imageWatchProc
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image/png", "--watch", root.captureScript, "image/png"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser {
      onRead: function(data) { root.addClipboardJson(data) }
    }
  }

  Timer {
    id: watchRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (!textWatchProc.running) textWatchProc.running = true
      if (!imageWatchProc.running) imageWatchProc.running = true
    }
  }

  // ---- UI ---------------------------------------------------------------
  // Same popup as the stock Wi-Fi panel: Omarchy's KeyboardPanel, anchored
  // under the bar icon (also when opened with the keyboard shortcut), with
  // its look, outside-click dismissal and one-popup-at-a-time coordination.
  // Without the bar icon it opens at the top-left corner.
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorButton
    bar: root.anchorBar
    // The bar widget owns the popout (stock underline under the icon); its
    // close() closes this overlay.
    owner: root.anchorWidget || root
    open: root.opened
    focusTarget: searchInput
    contentWidth: root.cardWidth
    contentHeight: root.cardHeight

    Item {
      anchors.fill: parent

      Item {
        id: confirmLayer
        anchors.fill: parent
        z: root.clearConfirmOpen ? 20 : 0

        ConfirmDialog {
          id: clearConfirm
          anchors.fill: parent
          opened: root.clearConfirmOpen
          z: 10
          message: "Delete clipboard history? Pinned items stay."
          confirmText: "Delete"
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelClearHistory()
          onConfirmed: root.confirmClearHistory()
        }
      }

      Column {
        anchors.fill: parent
        spacing: root.contentSpacing

        // Search line + entry count
        Item {
          width: parent.width
          height: root.headerHeight

          TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.right: incognitoBadge.visible ? incognitoBadge.left : countLabel.left
            anchors.rightMargin: Style.space(12)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            verticalAlignment: TextInput.AlignVCenter
            focus: true
            clip: true
            selectByMouse: true
            persistentSelection: false
            color: root.foreground
            selectionColor: root.selectedBackground
            selectedTextColor: root.selectedText
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { root.handleSearchKey(event) }
            Keys.onReleased: function(event) { root.handleSearchKeyRelease(event) }
            onTextChanged: if (text !== root.filterText) root.setFilter(text)

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: searchInput.text === ""
              textFormat: Text.PlainText
              text: "Search clipboard… (F1 for keys)"
              color: root.foreground
              opacity: 0.58
              font: searchInput.font
              elide: Text.ElideRight
            }
          }

          // Small badge, only while incognito is on.
          Rectangle {
            id: incognitoBadge
            visible: root.privateMode
            anchors.right: countLabel.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: badgeText.implicitWidth + Style.space(12)
            height: badgeText.implicitHeight + Style.space(4)
            radius: root.cornerRadius
            color: Util.alpha(root.accent, 0.16)

            Text {
              id: badgeText
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "󰗹 Incognito"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          MouseArea {
            id: badgeMouse
            anchors.fill: incognitoBadge
            visible: incognitoBadge.visible
            hoverEnabled: true

            PanelToolTip {
              visible: badgeMouse.containsMouse
              text: root.fluxPaused ? "Incognito: copies not saved, Flux sync paused" : "Incognito: copies not saved"
            }
          }

          Text {
            id: countLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: ClipboardHistory.countLabel(root.history.length, ClipboardHistory.pinnedCount(root.history), displayModel.count, root.filterText !== "")
            color: root.dimText
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - footer.implicitHeight - root.contentSpacing * 2

          // Shortcuts & settings view, shown over the list.
          Rectangle {
            id: infoView
            anchors.fill: parent
            visible: root.infoOpen
            z: 5
            color: root.background

            Flickable {
              id: infoFlick
              anchors.fill: parent
              clip: true
              contentWidth: width
              contentHeight: infoColumn.implicitHeight
              boundsBehavior: Flickable.StopAtBounds
              flickDeceleration: 2500
              maximumFlickVelocity: 6000

              KineticScroll {
                flickable: infoFlick
                wheelStep: root.rowHeight * 3
              }

              Column {
                id: infoColumn
                width: infoFlick.width
                spacing: Style.space(2)

                Text {
                  text: "SETTINGS"
                  color: root.dimText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  topPadding: Style.space(2)
                  bottomPadding: Style.space(4)
                  leftPadding: Style.space(10)
                }

                Repeater {
                  model: [
                    { key: "incognito", label: "󰗹  Incognito", value: root.privateMode ? "on" : "off", hint: "Ctrl+I" },
                    { key: "clear", label: "󰩺  Clear history", value: "", hint: "Shift+Del" },
                    { key: "back", label: "󰁍  Back to the list", value: "", hint: "Esc" }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: infoColumn.width
                    height: root.rowHeight
                    radius: root.cornerRadius
                    readonly property bool current: root.infoIndex === root.infoActions.indexOf(modelData.key)
                    color: current ? root.selectedBackground : (infoRowMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")

                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(10)
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: parent.modelData.label
                      color: parent.modelData.key === "incognito" && root.privateMode ? root.accent : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                    }

                    Row {
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(10)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(10)

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: parent.parent.modelData.hint
                        color: root.dimText
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                      }

                      Rectangle {
                        visible: parent.parent.modelData.key === "incognito"
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(Style.font.body * 2.2)
                        height: Math.round(Style.font.body * 1.2)
                        radius: height / 2
                        color: root.privateMode ? root.accent : Util.alpha(root.foreground, 0.22)

                        Rectangle {
                          width: parent.height - Style.space(4)
                          height: width
                          radius: width / 2
                          y: Style.space(2)
                          x: root.privateMode ? parent.width - width - Style.space(2) : Style.space(2)
                          color: root.privateMode ? root.background : root.foreground
                          Behavior on x { NumberAnimation { duration: 120 } }
                        }
                      }
                    }

                    MouseArea {
                      id: infoRowMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { root.infoIndex = root.infoActions.indexOf(parent.modelData.key); root.runInfoAction(parent.modelData.key) }
                    }
                  }
                }

                // Flux section (the header phone icon opens the view here).
                Text {
                  id: fluxSection
                  text: "FLUX"
                  color: root.dimText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  topPadding: Style.space(10)
                  bottomPadding: Style.space(4)
                  leftPadding: Style.space(10)
                }

                Repeater {
                  model: [
                    { icon: "󰄜", label: root.phoneOnline ? (root.phoneName || "Phone") : "No phone connected", value: root.fluxStatusText },
                    { icon: "󰓦", label: "Last sync", value: ClipboardHistory.agoLabel(root.lastSync, root.nowSec) }
                  ]
                  delegate: infoValueRow
                }

                Rectangle {
                  id: sendRow
                  readonly property bool enabled: root.phoneOnline && !root.fluxPaused
                  readonly property bool current: root.infoIndex === root.infoActions.indexOf("send")
                  width: infoColumn.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: current ? root.selectedBackground : (sendMouse.containsMouse && enabled ? Util.alpha(root.foreground, 0.08) : "transparent")
                  opacity: enabled ? 1 : 0.5

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: "󰒊  Send current clipboard"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: "Ctrl+S"
                    color: root.dimText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: sendRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { root.infoIndex = root.infoActions.indexOf("send"); root.sendCurrentClipboard() }
                  }
                }

                Text {
                  text: "HISTORY"
                  color: root.dimText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  topPadding: Style.space(10)
                  bottomPadding: Style.space(4)
                  leftPadding: Style.space(10)
                }

                Repeater {
                  model: [
                    { icon: "󰋚", label: "Keeps the last " + root.historyLimit, value: "pinned items kept" }
                  ]
                  delegate: infoValueRow
                }

                Text {
                  text: "SHORTCUTS"
                  color: root.dimText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  topPadding: Style.space(10)
                  bottomPadding: Style.space(4)
                  leftPadding: Style.space(10)
                }

                Repeater {
                  model: [
                    ["Enter", "paste"],
                    ["Shift+Enter", "copy only"],
                    ["Alt+Enter", "open"],
                    ["Alt+1…9", "quick paste"],
                    ["↑ ↓  Ctrl+K Ctrl+J", "move"],
                    ["→ ←", "row actions"],
                    ["Ctrl+P", "pin / unpin"],
                    ["Del", "delete"],
                    ["Ctrl+S", "send via Flux"],
                    ["Shift+Del", "clear history"],
                    ["Ctrl+I", "incognito"],
                    ["Ctrl+U", "clear search"],
                    ["F1  Ctrl+/", "this view"],
                    ["Esc", "back / close"],
                    ["Alt+V", "open from anywhere"],
                    ["Super+Shift+Ctrl+V", "incognito from anywhere"]
                  ]
                  delegate: Item {
                    required property var modelData
                    width: infoColumn.width
                    height: root.rowHeight

                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(10)
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: parent.modelData[0]
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }

                    Text {
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(10)
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: parent.modelData[1]
                      color: root.dimText
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }
                  }
                }
              }
            }
          }

          // Read-only settings row, styled like a list row (icon + label, value right).
          Component {
            id: infoValueRow
            Item {
              required property var modelData
              width: infoColumn.width
              height: root.rowHeight

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: valueText.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: parent.modelData.icon + "  " + parent.modelData.label
                color: root.foreground
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
              }

              Text {
                id: valueText
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: parent.modelData.value
                color: root.dimText
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }

          Item {
            anchors.fill: parent
            visible: !root.infoOpen

            Item {
              width: parent.width
              height: parent.height
              clip: true

              ListView {
                id: resultList
                anchors.fill: parent
                model: displayModel
                clip: true
                spacing: Style.space(2)
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 2500
                maximumFlickVelocity: 6000

                KineticScroll {
                  flickable: resultList
                  wheelStep: root.rowHeight * 3
                }

                section.property: "sectionName"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                  required property string section
                  width: ListView.view.width
                  height: section ? Style.font.caption + Style.space(12) : 0
                  Text {
                    visible: parent.section !== ""
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(12)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Style.space(3)
                    text: parent.section.toUpperCase()
                    color: root.dimText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.2
                  }
                }

                delegate: Rectangle {
                  id: row
                  required property int index
                  required property string entryType
                  required property string previewText
                  required property string fullText
                  required property string previewImage
                  required property bool pinned
                  required property int slot
                  required property bool fromPhone
                  required property int historyIndex

                  readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
                  readonly property bool armed: root.armedDeleteIndex !== -1 && historyIndex === root.armedDeleteIndex
                  readonly property bool showActions: hasCursor || rowMouse.containsMouse

                  width: ListView.view.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: armed ? Util.alpha(root.urgent, 0.85) : (hasCursor ? root.selectedBackground : "transparent")

                  MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: function(mouse) { root.selectFromPointer(row.index, row, mouse) }
                    onClicked: {
                      root.cursorActive = true
                      root.selectedIndex = row.index
                      root.activateIndex(row.index)
                    }
                  }

                  Row {
                    id: rowContent
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(4)
                    anchors.topMargin: Style.space(2)
                    anchors.bottomMargin: Style.space(2)
                    spacing: Style.space(10)

                    Image {
                      visible: row.previewImage.length > 0
                      width: visible ? parent.height : 0
                      height: parent.height
                      source: row.previewImage
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      smooth: true
                    }

                    Text {
                      textFormat: Text.PlainText
                      width: parent.width - actions.width - parent.spacing - (row.previewImage.length > 0 ? parent.height + parent.spacing : 0)
                      height: parent.height
                      text: row.armed ? "Press Del again to delete" : row.previewText
                      color: row.armed ? "#ffffff" : (row.hasCursor ? root.selectedText : root.foreground)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      font.bold: row.armed
                      opacity: !row.armed && (row.entryType === "image" || row.entryType === "file") ? 0.72 : 1.0
                      elide: Text.ElideRight
                      wrapMode: Text.NoWrap
                      verticalAlignment: Text.AlignVCenter
                    }

                    // Pin + delete buttons (on hover/cursor), shortcut hint otherwise.
                    Row {
                      id: actions
                      height: parent.height
                      spacing: Style.space(2)

                      // "From phone" label (Flux), on text that arrived from the phone.
                      Item {
                        visible: row.fromPhone && !row.armed
                        width: visible ? phoneLabel.implicitWidth + Style.space(8) : 0
                        height: actions.height

                        Text {
                          id: phoneLabel
                          anchors.left: parent.left
                          anchors.verticalCenter: parent.verticalCenter
                          textFormat: Text.PlainText
                          text: "From phone"
                          color: row.hasCursor ? root.selectedText : root.dimText
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          font.bold: true
                        }
                      }

                      Item {
                        visible: !row.showActions && !row.armed && row.slot <= 9
                        width: visible ? slotHint.implicitWidth + Style.space(6) : 0
                        height: actions.height

                        Text {
                          id: slotHint
                          anchors.left: parent.left
                          anchors.verticalCenter: parent.verticalCenter
                          text: "Alt+" + row.slot
                          color: Qt.darker(root.foreground, 1.5)
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                        }
                      }

                      Repeater {
                        model: [
                          { glyph: "󰄜", tip: "send", show: row.showActions && !row.armed && root.phoneOnline && row.entryType === "text" },
                          { glyph: "󰩺", tip: "delete", show: row.showActions || row.armed },
                          { glyph: row.pinned ? "󰐃" : "󰤱", tip: "pin", show: !row.armed && (row.showActions || row.pinned) }
                        ]
                        delegate: Rectangle {
                          required property var modelData
                          visible: modelData.show
                          width: visible ? actions.height : 0
                          height: actions.height
                          radius: root.cornerRadius
                          readonly property bool keyFocused: row.hasCursor && root.focusedAction === modelData.tip
                          color: keyFocused ? Util.alpha(row.armed ? "#ffffff" : root.accent, 0.28)
                            : (btnMouse.containsMouse ? Util.alpha(root.foreground, 0.10) : "transparent")
                          border.width: keyFocused ? Math.max(1, Style.space(2)) : 0
                          border.color: row.armed ? "#ffffff" : root.accent

                          Text {
                            anchors.centerIn: parent
                            text: parent.modelData.glyph
                            color: row.armed ? "#ffffff" : (parent.modelData.tip === "pin" && row.pinned ? root.accent : (row.hasCursor ? root.selectedText : root.foreground))
                            opacity: parent.keyFocused || (parent.modelData.tip === "pin" && row.pinned) ? 1 : 0.75
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.title
                          }

                          MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runRowAction(parent.modelData.tip, row.index)
                          }

                          PanelToolTip {
                            visible: btnMouse.containsMouse && parent.modelData.tip === "send"
                            text: "Send via Flux"
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0 && !root.infoOpen

            Text {
              text: root.privateMode && root.history.length === 0 ? "󰗹" : "󰅌"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.history.length === 0 ? "Clipboard is empty" : "No matches for “" + root.filterText + "”"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }
        }

        // Footer, one row: Clear history left; Incognito switch and gear right.
        Item {
          id: footer
          width: parent.width
          implicitHeight: root.footerRowHeight + root.footerGap
          height: implicitHeight

          Item {
            y: root.footerGap
            width: parent.width
            height: root.footerRowHeight

              Rectangle {
                anchors.left: parent.left
                width: clearLabel.implicitWidth + Style.space(16)
                height: root.footerRowHeight
                radius: root.cornerRadius
                color: clearMouse.containsMouse ? Util.alpha(root.foreground, 0.10) : Util.alpha(root.foreground, 0.04)

                Text {
                  id: clearLabel
                  anchors.centerIn: parent
                  text: "󰩺  Clear history"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                MouseArea {
                  id: clearMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.requestClearHistory()
                }
              }

              // Incognito on/off switch (also Ctrl+I, or right-click the bar icon).
              Rectangle {
                id: incognitoSwitch
                anchors.right: phoneButton.visible ? phoneButton.left : gearButton.left
                anchors.rightMargin: Style.space(8)
                width: incognitoRow.implicitWidth + Style.space(16)
                height: root.footerRowHeight
                radius: root.cornerRadius
                color: incognitoMouse.containsMouse ? Util.alpha(root.foreground, 0.10)
                  : (root.privateMode ? Util.alpha(root.accent, 0.16) : Util.alpha(root.foreground, 0.04))

                Row {
                  id: incognitoRow
                  anchors.centerIn: parent
                  spacing: Style.space(8)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: "󰗹  Incognito"
                    color: root.privateMode ? root.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Style.font.body * 2.2)
                    height: Math.round(Style.font.body * 1.2)
                    radius: height / 2
                    color: root.privateMode ? root.accent : Util.alpha(root.foreground, 0.22)

                    Rectangle {
                      width: track.height - Style.space(4)
                      height: width
                      radius: width / 2
                      y: Style.space(2)
                      x: root.privateMode ? track.width - width - Style.space(2) : Style.space(2)
                      color: root.privateMode ? root.background : root.foreground
                      Behavior on x { NumberAnimation { duration: 120 } }
                    }
                  }

                }

                MouseArea {
                  id: incognitoMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setPrivate(!root.privateMode, false)
                }
              }

            // Flux phone button: state as icon + tooltip; click opens Flux.
            Rectangle {
              id: phoneButton
              visible: root.phoneIcon !== ""
              anchors.right: gearButton.left
              anchors.rightMargin: Style.space(8)
              anchors.top: parent.top
              width: root.footerRowHeight
              height: root.footerRowHeight
              radius: root.cornerRadius
              color: phoneMouse.containsMouse ? Util.alpha(root.foreground, 0.10) : Util.alpha(root.foreground, 0.04)

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: root.phoneIcon === "online" ? "󰄜" : "󰥐"
                color: root.phoneIcon === "paused" ? root.accent
                  : (root.phoneIcon === "online" ? root.foreground : root.dimText)
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
              }

              MouseArea {
                id: phoneMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openFlux()
              }

              PanelToolTip {
                visible: phoneMouse.containsMouse
                text: ClipboardHistory.phoneTooltip(root.phoneIcon, root.phoneName)
              }
            }

            // Shortcuts & settings (also F1 or Ctrl+/).
            Rectangle {
              id: gearButton
              anchors.right: parent.right
              anchors.top: parent.top
              width: root.footerRowHeight
              height: root.footerRowHeight
              radius: root.cornerRadius
              color: root.infoOpen ? Util.alpha(root.accent, 0.20)
                : (gearMouse.containsMouse ? Util.alpha(root.foreground, 0.10) : Util.alpha(root.foreground, 0.04))

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "󰒓"
                color: root.infoOpen ? root.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
              }

              MouseArea {
                id: gearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.infoOpen ? root.closeInfo() : root.openInfo()
              }

              PanelToolTip {
                visible: gearMouse.containsMouse
                text: "Shortcuts & settings (F1)"
              }
            }
          }
        }
      }
    }
  }
}
