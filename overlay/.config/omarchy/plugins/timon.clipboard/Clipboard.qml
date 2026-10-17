// timon.clipboard: clipboard history popup with the UX of GNOME Clipboard
// History (pinned items, private mode, regex search, Ctrl+N), built on
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
  property bool privateMode: false
  // Flux (fluxd) clipboard sync: paused by flux-pause.sh while private mode is on.
  property bool fluxPresent: false
  property bool fluxPaused: false
  property bool fluxResync: false
  property bool hasPinned: false
  property var history: []

  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")
  readonly property string dataDir: dataHome + "/timon.clipboard"
  readonly property string historyPath: dataDir + "/history.json"
  readonly property string statePath: dataDir + "/state.json"
  readonly property string captureScript: pluginDir + "/capture.sh"
  readonly property string helper: pluginDir + "/clipboard.sh"
  readonly property string fluxScript: pluginDir + "/flux-pause.sh"

  // Same [menu] surface tokens as the stock clipboard, so every theme styles it.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color accent: Color.accent
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int footerHeight: Math.max(Style.space(26), Style.font.caption + Style.spacing.controlPaddingY * 2)
  property int bannerHeight: privateMode ? Math.max(Style.space(28), Style.font.body + Style.spacing.controlPaddingY * 2) : 0
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(875), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(640), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)

  // ---- open / close (shell host API) ------------------------------------
  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function close() {
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

  function status(arg) {
    return JSON.stringify({ private: root.privateMode, fluxPaused: root.fluxPaused, open: root.opened, entries: root.history.length, shown: displayModel.count })
  }

  // ---- private mode -----------------------------------------------------
  function setPrivate(value, notify) {
    var fluxWasPaused = root.fluxPaused
    root.privateMode = value
    stateFile.setText(JSON.stringify({ private: value }) + "\n")
    root.syncFlux()
    if (notify) {
      Quickshell.execDetached(["notify-send", "-a", "Clipboard", "-t", "2500",
        value ? "Clipboard private mode on" : "Clipboard private mode off",
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

  // Make Flux match private mode (flux-pause.sh sync reads state.json).
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
  }

  // Deleting what is on the clipboard right now puts the next newest entry
  // back on it (GNOME does the same), or empties it.
  function restoreLatest() {
    if (root.privateMode) return
    restoreTimer.restart()
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
    var wasCurrent = row.historyIndex === 0
    root.history = ClipboardHistory.removeEntryAt(root.history, row.historyIndex)
    root.saveHistory()
    if (wasCurrent) root.restoreLatest()

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
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  // Ctrl+N: Nth history entry, Alt+N: Nth pinned entry (as shown).
  function activateSlot(pinned, slot) {
    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (row.pinned === pinned && row.slot === slot) {
        root.activateIndex(i)
        return
      }
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
  function copyIndex(index) { root.runOnIndex(index, "copy") }
  function openIndex(index) { root.runOnIndex(index, "open") }

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

    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    var alt = (event.modifiers & Qt.AltModifier) !== 0
    var shift = (event.modifiers & Qt.ShiftModifier) !== 0
    var action = ClipboardHistory.searchKeyAction({
      key: event.key, ctrl: ctrl, alt: alt, shift: shift,
      hasSelection: searchInput.selectedText.length > 0
    })
    var digit = event.key >= Qt.Key_1 && event.key <= Qt.Key_9 ? event.key - Qt.Key_0 : 0

    switch (action) {
    case "escape":
      if (root.filterText) root.setFilter("")
      else root.close()
      break
    case "slot": root.activateSlot(false, digit); break
    case "pinnedSlot": root.activateSlot(true, digit); break
    case "copySelection": root.copyText(searchInput.selectedText); break
    case "cutSelection":
      root.copyText(searchInput.selectedText)
      searchInput.remove(searchInput.selectionStart, searchInput.selectionEnd)
      break
    case "clearSearch": root.setFilter(""); break
    case "pin": if (root.cursorActive) root.togglePinDisplayIndex(root.selectedIndex); break
    case "private": root.setPrivate(!root.privateMode, false); break
    case "clear": root.requestClearHistory(); break
    case "delete": if (root.cursorActive) root.removeDisplayIndex(root.selectedIndex); break
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

  onFilterTextChanged: if (searchInput.text !== root.filterText) searchInput.text = root.filterText

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
  Component.onCompleted: initProc.running = true

  ListModel { id: displayModel }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
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

  // Give the history write a moment to land before the helper reads it.
  Timer {
    id: restoreTimer
    interval: 250
    onTriggered: {
      if (root.history.length > 0) Quickshell.execDetached([root.helper, "copy", "0"])
      else Quickshell.execDetached([root.helper, "clear"])
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
    command: [root.fluxScript, "sync"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var s = String(text).trim()
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
  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

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
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        // Search line + entry count
        Item {
          width: parent.width
          height: root.headerHeight

          TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.right: countLabel.left
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
            font.pixelSize: Style.font.heading
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { root.handleSearchKey(event) }
            onTextChanged: if (text !== root.filterText) root.setFilter(text)

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: searchInput.text === ""
              textFormat: Text.PlainText
              text: "Search clipboard…"
              color: root.foreground
              opacity: 0.58
              font: searchInput.font
              elide: Text.ElideRight
            }
          }

          Text {
            id: countLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText ? displayModel.count + " / " + root.history.length : String(root.history.length)
            color: root.foreground
            opacity: 0.45
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        // Private mode banner
        Rectangle {
          visible: root.privateMode
          width: parent.width
          height: root.bannerHeight
          radius: root.cornerRadius
          color: Util.alpha(root.accent, 0.14)

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "󰗹  Private mode – new copies are not saved" + (root.fluxPaused ? ", Flux sync paused" : "") + "  (Ctrl+P to turn off)"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.footerHeight - root.contentSpacing * (root.privateMode ? 3 : 2) - root.bannerHeight

          Row {
            anchors.fill: parent
            spacing: 0

            Item {
              width: parent.width / 2
              height: parent.height
              clip: true

              ListView {
                id: resultList
                anchors.fill: parent
                anchors.rightMargin: root.contentMargin
                model: displayModel
                clip: true
                spacing: Style.space(4)
                boundsBehavior: Flickable.StopAtBounds

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
                    color: root.foreground
                    opacity: 0.5
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
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

                  readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
                  readonly property bool showActions: hasCursor || rowMouse.containsMouse

                  width: ListView.view.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: hasCursor ? root.selectedBackground : "transparent"

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
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(8)
                    anchors.topMargin: Style.space(8)
                    anchors.bottomMargin: Style.space(8)
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
                      text: row.previewText
                      color: row.hasCursor ? root.selectedText : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      opacity: row.entryType === "image" || row.entryType === "file" ? 0.72 : 1.0
                      elide: Text.ElideRight
                      wrapMode: Text.NoWrap
                      verticalAlignment: Text.AlignVCenter
                    }

                    // Pin + delete buttons (on hover/cursor), shortcut hint otherwise.
                    Row {
                      id: actions
                      height: parent.height
                      spacing: Style.space(2)

                      Item {
                        visible: !row.showActions && row.slot <= 9
                        width: visible ? slotHint.implicitWidth + Style.space(6) : 0
                        height: actions.height

                        Text {
                          id: slotHint
                          anchors.left: parent.left
                          anchors.verticalCenter: parent.verticalCenter
                          text: (row.pinned ? "Alt+" : "Ctrl+") + row.slot
                          color: root.foreground
                          opacity: 0.32
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                      }

                      Repeater {
                        model: [
                          { glyph: row.pinned ? "󰐃" : "󰤱", tip: "pin", show: row.showActions || row.pinned },
                          { glyph: "󰆴", tip: "delete", show: row.showActions }
                        ]
                        delegate: Rectangle {
                          required property var modelData
                          visible: modelData.show
                          width: visible ? actions.height : 0
                          height: actions.height
                          radius: root.cornerRadius
                          color: btnMouse.containsMouse ? Util.alpha(root.foreground, 0.10) : "transparent"

                          Text {
                            anchors.centerIn: parent
                            text: parent.modelData.glyph
                            color: parent.modelData.tip === "pin" && row.pinned ? root.accent : (row.hasCursor ? root.selectedText : root.foreground)
                            opacity: parent.modelData.tip === "pin" && row.pinned ? 1 : 0.75
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.title
                          }

                          MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              if (parent.modelData.tip === "pin") root.togglePinDisplayIndex(row.index)
                              else root.removeDisplayIndex(row.index)
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // Full preview of the selected entry
            Item {
              width: parent.width / 2
              height: parent.height
              clip: true

              property var activeRow: displayModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count ? displayModel.get(root.selectedIndex) : null

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Style.normalBorderWidth
                color: Util.alpha(root.border, 0.28)
              }

              Text {
                textFormat: Text.PlainText
                visible: parent.activeRow && !parent.activeRow.previewImage
                anchors.fill: parent
                anchors.leftMargin: root.contentMargin
                text: parent.activeRow ? parent.activeRow.fullText : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                verticalAlignment: Text.AlignTop
              }

              Image {
                visible: parent.activeRow && parent.activeRow.previewImage
                anchors.fill: parent
                anchors.leftMargin: root.contentMargin
                source: parent.activeRow ? parent.activeRow.previewImage : ""
                fillMode: Image.PreserveAspectFit
                verticalAlignment: Image.AlignTop
                asynchronous: true
                smooth: true
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0

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

        // Footer: private switch, clear, key hints
        Item {
          width: parent.width
          height: root.footerHeight

          Row {
            id: footerButtons
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Repeater {
              model: [
                { id: "private", label: root.privateMode ? "󰗹  Private: on" : "󰗹  Private: off" },
                { id: "clear", label: "󰆴  Clear history" }
              ]
              delegate: Rectangle {
                required property var modelData
                width: footerLabel.implicitWidth + Style.space(16)
                height: root.footerHeight
                radius: root.cornerRadius
                color: footerMouse.containsMouse ? Util.alpha(root.foreground, 0.10)
                  : (modelData.id === "private" && root.privateMode ? Util.alpha(root.accent, 0.16) : Util.alpha(root.foreground, 0.04))

                Text {
                  id: footerLabel
                  anchors.centerIn: parent
                  text: parent.modelData.label
                  color: parent.modelData.id === "private" && root.privateMode ? root.accent : root.foreground
                  opacity: parent.modelData.id === "private" && root.privateMode ? 1 : 0.8
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  id: footerMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (parent.modelData.id === "private") root.setPrivate(!root.privateMode, false)
                    else root.requestClearHistory()
                  }
                }
              }
            }
          }

          Text {
            anchors.right: parent.right
            anchors.left: footerButtons.right
            anchors.leftMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            text: "↵ paste   ⇧↵ copy   Alt+↵ open   Ctrl+F pin   Del delete   ⇧Del clear   Ctrl+P private"
            color: root.foreground
            opacity: 0.45
            elide: Text.ElideLeft
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
