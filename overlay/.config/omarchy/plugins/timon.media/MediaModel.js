function isProxyPlayer(player) {
  var dbusName = String(player && player.dbusName || "").toLowerCase()
  var desktopEntry = String(player && player.desktopEntry || "").toLowerCase()
  return dbusName.indexOf("playerctld") !== -1 || desktopEntry === "playerctld"
}

function hasMetadata(player) {
  return !!(player && (player.trackTitle || player.trackArtist || player.identity || player.desktopEntry))
}

function hasTrackMetadata(player) {
  return !!(player && (player.trackTitle || player.trackArtist || player.trackAlbum || player.trackArtUrl))
}

function playerCanControl(player) {
  return !!(player && (player.canTogglePlaying || player.canPlay || player.canPause || player.canGoNext || player.canGoPrevious))
}

function canHandleAction(player, action) {
  if (!player) return false
  if (action === "next") return !!player.canGoNext
  if (action === "previous") return !!player.canGoPrevious
  if (action === "play") return !!(player.canPlay || player.canTogglePlaying)
  if (action === "pause") return !!(player.canPause || player.canTogglePlaying)
  if (action === "playPause") return !!(player.canTogglePlaying || player.canPlay || player.canPause)
  return false
}

function canCycleSource(player) {
  return !!(player && hasMetadata(player) && (player.isPlaying || player.canPlay))
}

function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function isPlaybackStream(node) {
  if (!node || !node.isStream) return false
  if (node.isSink === true) return true

  var mediaClass = String(node.type || "")
  return mediaClass.indexOf("Stream/Output/Audio") !== -1
    || mediaClass.indexOf("AudioOutStream") !== -1
    || mediaClass.indexOf("Output") !== -1
}

function streamLabelKey(label) {
  var key = String(label || "").toLowerCase()
  key = key.replace(/^pipewire alsa \[/, "")
  key = key.replace(/\]$/, "")
  key = key.replace(/^alsa playback \[/, "")
  key = key.replace(/[^a-z0-9]+/g, "")
  return key
}

function rawStreamLabel(node) {
  if (!node) return ""
  var p = nodeProps(node)
  return p["application.name"]
    || node.description
    || p["media.name"]
    || p["node.name"]
    || node.name
}

function playerAppLabel(player) {
  if (!player) return ""
  var dbus = String(player.dbusName || "")
  dbus = dbus.replace(/^org\.mpris\.MediaPlayer2\./, "")
  dbus = dbus.replace(/\.instance[0-9]+$/, "")
  return player.desktopEntry || player.identity || dbus
}

function playerHasPlaybackStream(player, playbackStreams) {
  var playerKey = streamLabelKey(playerAppLabel(player))
  if (!playerKey) return false

  var streams = Array.isArray(playbackStreams) ? playbackStreams : []
  for (var i = 0; i < streams.length; i++) {
    var streamKey = streamLabelKey(rawStreamLabel(streams[i]))
    if (!streamKey) continue
    if (streamKey === playerKey
        || streamKey.indexOf(playerKey) !== -1
        || playerKey.indexOf(streamKey) !== -1)
      return true
  }

  return false
}

function playerKey(player) {
  if (!player) return ""
  return String(player.dbusName || player.desktopEntry || player.identity || "")
}

function isBrowserPlayer(player) {
  var ident = String(player && player.identity || "").toLowerCase()
  var dbus = String(player && player.dbusName || "").toLowerCase()
  var desktop = String(player && player.desktopEntry || "").toLowerCase()
  return ident.indexOf("brave") !== -1
    || ident.indexOf("chrom") !== -1
    || dbus.indexOf("brave") !== -1
    || dbus.indexOf("chrom") !== -1
    || desktop.indexOf("brave") !== -1
    || desktop.indexOf("chrom") !== -1
}

function prettySiteLabel(appId, title) {
  var id = String(appId || "").toLowerCase()
  var t = String(title || "").trim()
  var sites = [
    { match: "x.com", label: "X" },
    { match: "twitter.com", label: "X" },
    { match: "youtube", label: "YouTube" },
    { match: "netflix", label: "Netflix" },
    { match: "twitch", label: "Twitch" }
  ]
  var site = ""
  for (var i = 0; i < sites.length; i++) {
    if (id.indexOf(sites[i].match) !== -1) {
      site = sites[i].label
      break
    }
  }
  if (!site) return t
  if (!t) return site
  var lower = t.toLowerCase()
  if (lower === "home / x" || lower === "x" || lower === site.toLowerCase()) return site
  var suffix = " / " + site
  if (t.length > suffix.length && t.slice(-suffix.length).toLowerCase() === suffix.toLowerCase()) {
    var head = t.slice(0, t.length - suffix.length).trim()
    return head || site
  }
  var pipe = " | " + site
  if (t.length > pipe.length && t.slice(-pipe.length).toLowerCase() === pipe.toLowerCase()) {
    var head2 = t.slice(0, t.length - pipe.length).trim()
    return head2 || site
  }
  return t
}

function displayTitle(player, windowHint) {
  if (!player) return ""
  if (player.trackTitle) return String(player.trackTitle)
  var hint = String(windowHint || "").trim()
  if (hint) return hint
  if (player.trackArtist) return String(player.trackArtist)
  return String(player.identity || player.desktopEntry || "Media")
}

function hasNowPlaying(player) {
  return !!(player && (player.trackTitle || player.trackArtist || player.isPlaying))
}

function dismissKey(player) {
  if (!player) return ""
  var dbus = String(player.dbusName || "")
  dbus = dbus.replace(/^org\.mpris\.MediaPlayer2\./, "")
  dbus = dbus.replace(/\.instance[0-9]+$/i, "")
  return String(dbus || player.desktopEntry || player.identity || "").toLowerCase()
}

function parseHiddenKeys(raw) {
  var keys = {}
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    var list = Array.isArray(parsed) ? parsed : (parsed && Array.isArray(parsed.hidden) ? parsed.hidden : [])
    for (var i = 0; i < list.length; i++) {
      var key = String(list[i] || "").toLowerCase()
      if (key) keys[key] = true
    }
  } catch (e) {
  }
  return keys
}

function serializeHiddenKeys(map) {
  var list = []
  var source = map || {}
  for (var key in source) {
    if (source[key]) list.push(String(key))
  }
  list.sort()
  return JSON.stringify({ hidden: list }, null, 2) + "\n"
}

function trackSignature(player) {
  if (!player) return ""
  return [
    player.trackTitle || "",
    player.trackArtist || "",
    player.trackAlbum || "",
    player.trackArtUrl || ""
  ].join("\u001f")
}

function trackChanged(previousSignature, player) {
  return trackSignature(player) !== String(previousSignature || "")
}

function labelFor(player) {
  if (!player) return ""
  return player.trackTitle || player.identity || player.desktopEntry || ""
}

function osdMessage(player, fallback) {
  if (!player) return fallback
  var label = labelFor(player)
  if (label && player.trackArtist) return label + " - " + player.trackArtist
  return label || fallback
}

if (typeof module !== "undefined") {
  module.exports = {
    isProxyPlayer: isProxyPlayer,
    hasMetadata: hasMetadata,
    hasTrackMetadata: hasTrackMetadata,
    playerCanControl: playerCanControl,
    canHandleAction: canHandleAction,
    canCycleSource: canCycleSource,
    nodeProps: nodeProps,
    isPlaybackStream: isPlaybackStream,
    streamLabelKey: streamLabelKey,
    rawStreamLabel: rawStreamLabel,
    playerAppLabel: playerAppLabel,
    playerHasPlaybackStream: playerHasPlaybackStream,
    playerKey: playerKey,
    isBrowserPlayer: isBrowserPlayer,
    prettySiteLabel: prettySiteLabel,
    displayTitle: displayTitle,
    hasNowPlaying: hasNowPlaying,
    dismissKey: dismissKey,
    parseHiddenKeys: parseHiddenKeys,
    serializeHiddenKeys: serializeHiddenKeys,
    trackSignature: trackSignature,
    trackChanged: trackChanged,
    labelFor: labelFor,
    osdMessage: osdMessage
  }
}
