import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Wired: LAN cable and USB phone tethering, next to the stock network panel.
// On the bar only while a wired link is plugged in. The popup shows one
// section per link with the stock Wi-Fi panel's detail fields and an on/off
// switch (nmcli device connect/disconnect). Data: ~/.local/bin/omarchy-wired-status.
Panel {
  id: root
  moduleName: "timon.wired"
  ipcTarget: "timon.wired"

  readonly property string tool: Quickshell.env("HOME") + "/.local/bin/omarchy-wired-status"
  property var links: []
  property var rates: ({})     // iface -> {rx, tx} bytes/s
  property var last: ({})      // iface -> {rx, tx, t}
  property var pending: ({})   // iface -> wanted on/off while a toggle runs
  readonly property bool shown: links.length > 0

  visible: shown
  implicitWidth: shown ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight
  onShownChanged: if (!shown && opened) close()

  function apply(text) {
    try { var l = JSON.parse(text) } catch (e) { return }
    if (!Array.isArray(l)) return
    var now = Date.now(), r = {}, n = {}
    for (var i = 0; i < l.length; i++) {
      var k = l[i].iface, p = root.last[k]
      if (p && now > p.t) r[k] = { rx: Math.max(0, (l[i].rx_bytes - p.rx) * 1000 / (now - p.t)), tx: Math.max(0, (l[i].tx_bytes - p.tx) * 1000 / (now - p.t)) }
      n[k] = { rx: l[i].rx_bytes, tx: l[i].tx_bytes, t: now }
    }
    root.rates = r; root.last = n; root.links = l
  }
  function isOn(link) {
    return root.pending[link.iface] !== undefined ? root.pending[link.iface] : link.state !== "off"
  }
  function setOn(link, on) {
    if (toggleProc.running) return
    var p = Object.assign({}, root.pending); p[link.iface] = on; root.pending = p
    toggleProc.command = [root.tool, on ? "on" : "off", link.iface]
    toggleProc.running = true
  }
  function title(link) {
    var base = link.kind === "usb" ? "USB tethering" : "Ethernet"
    return link.speed > 0 ? base + " (" + formatSpeed(link.speed) + ")" : base
  }
  function formatSpeed(mbps) { return mbps >= 1000 ? (mbps / 1000) + "gbit" : mbps + "mbit" }
  function formatBytes(n) {
    n = Number(n); if (!isFinite(n) || n < 0) n = 0
    if (n < 1024) return Math.round(n) + " B"
    if (n < 1048576) return (n / 1024).toFixed(1) + " KB"
    if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB"
    return (n / 1073741824).toFixed(2) + " GB"
  }
  function rate(link, key) { var r = root.rates[link.iface]; return r ? formatBytes(r[key]) + "/s" : "--" }
  function copy(value) { if (value) Quickshell.execDetached(["wl-copy", "--", value]) }

  Process { id: statusProc; command: [root.tool]; stdout: StdioCollector { onStreamFinished: root.apply(text) } }
  Process {
    id: toggleProc
    onExited: pendingClear.restart()
  }
  Timer { id: pendingClear; interval: 1500; onTriggered: { root.pending = ({}); if (!statusProc.running) statusProc.running = true } }
  // 1.5 s while the popup is open (live rates), 5 s for the bar icon.
  Timer {
    interval: root.opened ? 1500 : 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.links.length > 0 && root.links[0].kind === "usb" && root.links.length === 1 ? "󰕓" : "󰈀"
    opacity: root.links.some(function (l) { return l.state === "connected" }) ? 1.0 : 0.5
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(14)

        Repeater {
          model: root.links
          delegate: Column {
            id: section
            required property var modelData
            required property int index
            width: column.width
            spacing: Style.space(10)

            PanelSeparator { visible: section.index > 0; foreground: root.bar.foreground }

            Item {
              width: parent.width
              implicitHeight: Math.max(heroIcon.implicitHeight, heroText.implicitHeight, toggle.implicitHeight)

              Text {
                id: heroIcon
                textFormat: Text.PlainText
                text: section.modelData.kind === "usb" ? "󰕓" : "󰈀"
                color: root.bar.foreground
                opacity: root.isOn(section.modelData) ? 1.0 : 0.5
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                id: heroText
                anchors.left: heroIcon.right
                anchors.leftMargin: Style.space(12)
                anchors.right: toggle.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: root.title(section.modelData)
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: (section.modelData.state === "connected" ? (section.modelData.name || "Connected")
                         : section.modelData.state === "connecting" ? "Connecting…" : "Off")
                        + " · " + section.modelData.iface + (section.modelData.default ? " · default route" : "")
                  color: root.bar.foreground
                  opacity: 0.6
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }

              ToggleSwitch {
                id: toggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.isOn(section.modelData)
                busy: toggleProc.running
                foreground: root.bar.foreground
                onToggled: root.setOn(section.modelData, !root.isOn(section.modelData))
              }
            }

            GridLayout {
              visible: section.modelData.state !== "off"
              width: parent.width
              columns: 4
              columnSpacing: Style.space(20)
              rowSpacing: Style.spacing.labelGap

              InfoLabel { text: "Receiving" }
              DetailValue { text: root.rate(section.modelData, "rx") }
              InfoLabel { text: "Sending" }
              DetailValue { text: root.rate(section.modelData, "tx") }

              InfoLabel { text: "Downloaded" }
              DetailValue { text: root.formatBytes(section.modelData.rx_bytes) }
              InfoLabel { text: "Uploaded" }
              DetailValue { text: root.formatBytes(section.modelData.tx_bytes) }

              InfoLabel { text: "IP Address" }
              DetailValue { text: section.modelData.ip || "--"; copyable: !!section.modelData.ip }
              InfoLabel { text: "Gateway" }
              DetailValue { text: section.modelData.gateway || "--"; copyable: !!section.modelData.gateway }

              InfoLabel { text: "DNS" }
              DetailValue { text: (section.modelData.dns || []).join(", ") || "--"; copyable: (section.modelData.dns || []).length > 0 }
              InfoLabel { text: "Link" }
              DetailValue { text: section.modelData.speed > 0 ? root.formatSpeed(section.modelData.speed) : "--" }
            }
          }
        }
      }
    }
  }

  // Same look as the stock network panel's detail grid.
  component DetailValue: InfoValue {
    property bool copyable: false
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideLeft
    MouseArea {
      id: valueMouse
      anchors.fill: parent
      enabled: parent.copyable
      hoverEnabled: enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.copy(parent.text)
    }
    PanelToolTip {
      visible: valueMouse.enabled && valueMouse.containsMouse
      text: "Copy"
      fontFamily: root.bar.fontFamily
    }
  }
  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
