.pragma library

// Finding the web app a browser notification came from.
//
// A Chromium-family browser sends every web notification under its own name
// and with its own logo as app_icon, whichever site raised it. So a Messenger
// message from the Messenger web app lands as "Chromium" with the Chromium
// ball beside it, and so does Gmail, and so does Discord. What the browser
// does say is the site: the body opens with a link to its origin,
// `<a href="https://www.messenger.com/">www.messenger.com</a>`.
//
// Omarchy's web apps are desktop entries that launch a URL
// (`omarchy-launch-webapp https://messenger.com`, or a browser with
// `--app=https://...`), and each has its own icon. So the origin is matched
// against the URLs those entries launch, and the entry's icon is the answer.
//
// The index is built once and thrown away whenever the application set
// changes, so a web app installed while the shell is running is found without
// a restart.

var index = null
var indexedCount = -1

// Sites whose web app is usually installed under one address and which then
// notify from another, because the first redirects to the second.
var aliases = {
  "gmail.com": "mail.google.com"
}

function reset() {
  index = null
}

// "https://www.Messenger.com:443/t/1" -> "messenger.com:443". Ports are kept:
// two services on one self-hosted address are two different apps.
function hostOf(url) {
  var match = /^https?:\/\/([^\/?#]+)/i.exec(String(url || "").trim())
  if (!match) return ""
  var host = match[1].toLowerCase()
  var at = host.lastIndexOf("@")
  if (at >= 0) host = host.substring(at + 1)
  return host.replace(/^www\./, "")
}

// The URL a desktop entry launches, if it launches one.
function urlOf(command) {
  var args = command || []
  for (var i = 0; i < args.length; i++) {
    var arg = String(args[i] || "")
    if (arg.indexOf("--app=") === 0) arg = arg.substring(6)
    if (/^https?:\/\//i.test(arg)) return arg
  }
  return ""
}

function build(entries) {
  var map = ({})
  var list = entries || []
  for (var i = 0; i < list.length; i++) {
    var source = list[i]
    if (!source) continue
    var icon = String(source.icon || "")
    var host = hostOf(urlOf(source.command))
    if (host === "" || icon === "") continue
    // First entry wins, so two web apps for one site do not trade places
    // between reloads.
    if (!map.hasOwnProperty(host)) map[host] = icon
    var alias = aliases[host]
    if (alias !== undefined && !map.hasOwnProperty(alias)) map[alias] = icon
  }
  return map
}

// The icon NAME of the web app a notification body points at, or "" when the
// body names no origin or no installed web app serves it. Resolving the name
// is the caller's job, as it is for app_icon.
function lookup(body, entries) {
  var match = /^\s*<a\s+href\s*=\s*["']([^"']+)["']/i.exec(String(body || ""))
  if (!match) return ""
  var host = hostOf(match[1])
  if (host === "") return ""

  var list = entries || []
  if (index === null || indexedCount !== list.length) {
    index = build(list)
    indexedCount = list.length
  }

  // m.facebook.com has no web app of its own, but facebook.com might. Walk up
  // one label at a time, stopping short of the bare top-level domain.
  while (host.indexOf(".") > 0) {
    if (index.hasOwnProperty(host)) return index[host]
    host = host.substring(host.indexOf(".") + 1)
  }
  return ""
}
