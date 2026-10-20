import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "timon.media"

  // Cloned bars (timon.bar) get a service-less shell facade, so
  // firstPartyServiceFor() is always null. Read MPRIS directly then.
  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
    || bar?.shell?.firstPartyServiceFor("timon.media")
    || null
  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var mprisActive: {
    var list = root.mprisPlayers
    var paused = null
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p || !(p.trackTitle || p.trackArtist)) continue
      if (p.isPlaying) return p
      if (!paused) paused = p
    }
    return paused
  }
  readonly property var activePlayer: (mediaService && mediaService.activePlayer) ? mediaService.activePlayer : mprisActive
  readonly property var sourcePlayers: mediaService && mediaService.sourcePlayers ? mediaService.sourcePlayers : (mprisActive ? [mprisActive] : [])

  readonly property bool hasMedia: mediaService ? !!mediaService.hasMedia
    : (activePlayer !== null && !!(activePlayer.trackTitle || activePlayer.trackArtist))
  readonly property string playIcon: activePlayer && activePlayer.isPlaying ? "󰏤" : "󰐊"
  // The service adds the browser tab/site title when a browser player has no track title.
  readonly property string title: mediaService && mediaService.title ? String(mediaService.title)
    : (activePlayer ? String(activePlayer.trackTitle || "") : "")
  readonly property string artist: activePlayer ? String(activePlayer.trackArtist || "") : ""

  function playerKey(player) {
    if (root.mediaService && typeof root.mediaService.playerKey === "function")
      return root.mediaService.playerKey(player)
    if (!player) return ""
    return String(player.identity || player.desktopEntry || player.trackTitle || "")
  }

  function runMedia(action, player) {
    var target = player || root.activePlayer
    if (root.mediaService && typeof root.mediaService.runAction === "function") {
      root.mediaService.runAction(action, false, root.playerKey(target))
      return
    }
    if (!target) return
    if (action === "next" && target.canGoNext) target.next()
    else if (action === "previous" && target.canGoPrevious) target.previous()
    else if (action === "playPause") {
      if (target.canTogglePlaying) target.togglePlaying()
      else if (target.isPlaying && target.canPause) target.pause()
      else if (!target.isPlaying && target.canPlay) target.play()
    }
  }
  readonly property string nowPlaying: {
    var song = String(root.title || "").trim()
    var who = String(root.artist || "").trim()
    // "<title> | <artist>"; just the title when there is no artist.
    if (song && who) return song + " | " + who
    return song || who
  }
  property int maxLabelChars: Number(setting("maxLabelChars", 15))
  readonly property string barNowPlaying: {
    var text = root.nowPlaying
    var maxChars = Math.max(0, root.maxLabelChars)
    if (text.length <= maxChars) return text
    // Don't leave a dangling " |" when the cut lands right after the title.
    return text.slice(0, maxChars).replace(/\s*\|?\s*$/, "")
  }
  readonly property bool canMarquee: root.nowPlaying.length > root.maxLabelChars

  Component.onCompleted: console.log("timon.media bar label maxChars=" + maxLabelChars
    + " nowPlayingLen=" + nowPlaying.length
    + " barNowPlaying=" + JSON.stringify(barNowPlaying))

  property bool popupOpen: false

  function close() { popupOpen = false }

  // Clicking the track info in the popup focuses the playing app's window.
  function focusSpotifyWindow() {
    if (focusSpotifyProcess.running) focusSpotifyProcess.running = false
    focusSpotifyProcess.running = true
    root.popupOpen = false
  }
  onHasMediaChanged: if (!hasMedia) popupOpen = false
  property real maxLabelWidth: 240

  visible: hasMedia
  implicitWidth: hasMedia ? row.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.playIcon
      color: activePlayer && activePlayer.isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    Item {
      id: labelClip
      // Idle width is the truncated 15-char label. The hover scroller is a
      // sibling that must not change that width; clip + inner layer matches
      // how the tray drawer keeps overflowing content off the bar.
      width: Math.min(root.maxLabelWidth, idleLabel.implicitWidth)
      height: Math.max(glyph.height, idleLabel.implicitHeight)
      implicitWidth: width
      implicitHeight: height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.vertical && root.barNowPlaying !== ""

      readonly property bool scrolling: root.canMarquee && (hoverArea.containsMouse || popup.open)
      readonly property real marqueeDistance: marqueeCopy.implicitWidth + marqueeRow.spacing
      readonly property int marqueeDuration: Math.max(6000, Math.round(labelClip.marqueeDistance * 50))

      Text {
        id: idleLabel
        textFormat: Text.PlainText
        text: root.barNowPlaying
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
        visible: !labelClip.scrolling
      }

      Row {
        id: marqueeRow
        spacing: Math.max(Style.space(32), labelClip.width)
        anchors.verticalCenter: parent.verticalCenter
        visible: labelClip.scrolling
        layer.enabled: true
        x: 0

        Text {
          id: marqueeCopy
          textFormat: Text.PlainText
          text: root.nowPlaying
          color: root.bar.barForeground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          textFormat: Text.PlainText
          text: root.nowPlaying
          color: root.bar.barForeground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      SequentialAnimation {
        id: marqueeAnim
        running: labelClip.scrolling
        loops: Animation.Infinite
        onRunningChanged: if (!running) marqueeRow.x = 0

        PauseAnimation { duration: 700 }
        NumberAnimation {
          target: marqueeRow
          property: "x"
          from: 0
          to: -labelClip.marqueeDistance
          duration: labelClip.marqueeDuration
          easing.type: Easing.Linear
        }
      }

      onScrollingChanged: if (scrolling) marqueeRow.x = 0
    }
  }

  Connections {
    target: root
    function onNowPlayingChanged() {
      marqueeRow.x = 0
      if (labelClip.scrolling) marqueeAnim.restart()
    }
  }

  // Window of whichever player is shown (Brave/YouTube/Netflix tab, Telegram,
  // mpv, Spotify, ...): see focus-player.py. Starts Spotify if nothing plays.
  Process {
    id: focusSpotifyProcess
    readonly property string script: decodeURIComponent(String(Qt.resolvedUrl("focus-player.py")).replace(/^file:\/\//, ""))
    command: [script,
      root.activePlayer ? String(root.activePlayer.dbusName || "") : "",
      root.activePlayer ? String(root.activePlayer.identity || "") : "",
      root.activePlayer ? String(root.activePlayer.desktopEntry || "") : "",
      root.activePlayer ? String(root.activePlayer.trackTitle || "") : ""]
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton) {
        root.runMedia("next")
      } else if (mouse.button === Qt.RightButton) {
        root.runMedia("playPause")
      } else {
        root.popupOpen = !root.popupOpen
      }
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      // Physical direction: undo the natural-scroll flip (wheel.inverted),
      // like the other bar icons (PhysicalWheel.qml in timon.audio).
      var dy = wheel.inverted ? -wheel.angleDelta.y : wheel.angleDelta.y
      if (dy > 0) root.runMedia("previous")
      else if (dy < 0) root.runMedia("next")
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Item {
        width: parent.width
        height: infoRow.implicitHeight

        Row {
          id: infoRow
          spacing: Style.space(10)
          width: parent.width

          BorderSurface {
            width: Style.space(64)
            height: Style.space(64)
            radius: Style.spacing.labelGap
            color: Style.normalFillFor(root.bar.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

            Image {
              anchors.fill: parent
              anchors.margins: Style.space(2)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
              visible: source !== ""
            }

            Text {
              anchors.centerIn: parent
              visible: !root.activePlayer || !root.activePlayer.trackArtUrl
              text: "󰝚"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.displayLarge
            }
          }

          Column {
            spacing: Style.space(4)
            width: parent.width - Style.space(74)

            MarqueeLabel {
              width: parent.width
              text: root.title || "Nothing playing"
              color: root.bar.foreground
              fontFamily: root.bar.fontFamily
              pixelSize: Style.font.subtitle
              bold: true
              running: popup.open
            }

            MarqueeLabel {
              width: parent.width
              text: root.artist
              color: Qt.darker(root.bar.foreground, 1.3)
              fontFamily: root.bar.fontFamily
              pixelSize: Style.font.bodySmall
              running: popup.open
              visible: text !== ""
            }

            MarqueeLabel {
              width: parent.width
              text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
              color: Qt.darker(root.bar.foreground, 1.6)
              fontFamily: root.bar.fontFamily
              pixelSize: Style.font.caption
              running: popup.open
              visible: text !== ""
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          z: 20
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusSpotifyWindow()
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.runMedia("previous")
        }

        Button {
          iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.runMedia("playPause")
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.runMedia("next")
        }
      }

      PanelSeparator {
        visible: root.sourcePlayers.length > 0
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 0
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.playerKey(root.activePlayer) === root.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: hideButton.left
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                MarqueeLabel {
                  width: parent.width
                  text: sourceRow.sourceTitle
                  color: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  pixelSize: Style.font.bodySmall
                  bold: sourceRow.selected
                  running: popup.open
                }

                MarqueeLabel {
                  width: parent.width
                  text: sourceRow.sourceDetail
                  color: Qt.darker(root.bar.foreground, 1.5)
                  fontFamily: root.bar.fontFamily
                  pixelSize: Style.font.caption
                  running: popup.open
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              anchors.rightMargin: hideButton.width + Style.space(8)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }

            Rectangle {
              id: hideButton
              z: 2
              anchors.right: parent.right
              anchors.rightMargin: sourceRow.borderRight + Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(16)
              height: width
              radius: width / 2
              color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b,
                             hideMouse.containsMouse ? 0.25 : 0.15)

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "×"
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                color: root.bar.foreground
                opacity: 0.8
              }

              MouseArea {
                id: hideMouse
                anchors.fill: parent
                anchors.margins: -Style.space(3)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.mediaService) root.mediaService.hideSource(sourceRow.player)
              }
            }
          }
        }
      }
    }
  }
}
