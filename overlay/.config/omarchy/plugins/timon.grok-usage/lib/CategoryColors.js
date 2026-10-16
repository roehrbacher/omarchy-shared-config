.pragma library

// Three (or more) clearly different category colors from the active Omarchy
// theme's palette (theme/colors.toml, the file the shell's Color singleton
// reads). The accent comes first; the rest are the theme hues farthest apart
// from those already chosen, so they follow theme switches.

var CANDIDATES = [
  ["accent"], ["blue", "color4"], ["green", "color2"], ["magenta", "color5"],
  ["yellow", "color3"], ["cyan", "color6"], ["orange"], ["red", "color1"]
]
var MIN_HUE_GAP = 40      // degrees between chosen hues
var MIN_CONTRAST = 2.2    // against the panel background
var MIN_SATURATION = 0.18

function parse(raw) {
  var out = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (m && !out.hasOwnProperty(m[1])) out[m[1]] = m[2].toLowerCase()
  }
  return out
}

function rgb(hex) {
  var n = parseInt(String(hex).slice(1), 16)
  return [(n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255]
}

function lum(c) {
  function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
  return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])
}

function contrast(a, b) {
  var la = lum(a), lb = lum(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

function hueSat(c) {
  var max = Math.max(c[0], c[1], c[2]), min = Math.min(c[0], c[1], c[2]), d = max - min
  var h = 0
  if (d > 0) {
    if (max === c[0]) h = ((c[1] - c[2]) / d) % 6
    else if (max === c[1]) h = (c[2] - c[0]) / d + 2
    else h = (c[0] - c[1]) / d + 4
    h = (h * 60 + 360) % 360
  }
  return { h: h, s: max > 0 ? d / max : 0 }
}

function gap(a, b) { var d = Math.abs(a - b) % 360; return d > 180 ? 360 - d : d }

// palette: parse() result. background: "#rrggbb" of the panel surface.
// Returns { colors: [...hex], names: [...] }.
function pick(palette, background, count) {
  count = count || 3
  var bg = rgb(background || palette.background || "#000000")
  var pool = []
  for (var i = 0; i < CANDIDATES.length; i++) {
    var keys = CANDIDATES[i], hex = ""
    for (var k = 0; k < keys.length && !hex; k++) hex = palette[keys[k]] || ""
    if (!hex) continue
    var c = rgb(hex), hs = hueSat(c)
    pool.push({ name: keys[0], hex: hex, h: hs.h,
                ok: hs.s >= MIN_SATURATION && contrast(c, bg) >= MIN_CONTRAST })
  }
  var chosen = []
  var usable = pool.filter(function (p) { return p.ok })
  if (usable.length > 0) chosen.push(usable[0])
  while (chosen.length < count) {
    var best = null, bestGap = -1
    for (var j = 0; j < usable.length; j++) {
      if (chosen.indexOf(usable[j]) >= 0) continue
      var g = 360
      for (var q = 0; q < chosen.length; q++) g = Math.min(g, gap(usable[j].h, chosen[q].h))
      if (g > bestGap) { best = usable[j]; bestGap = g }
    }
    if (!best || bestGap < MIN_HUE_GAP) break
    chosen.push(best)
  }
  var colors = chosen.map(function (p) { return p.hex })
  var names = chosen.map(function (p) { return p.name })
  // Fallback for monochrome themes or coinciding hues: foreground, muted,
  // then lighter/darker steps of what exists, so slices still differ.
  var extras = [["foreground", palette.foreground], ["muted", palette.muted || palette.color8]]
  for (var e = 0; e < extras.length && colors.length < count; e++) {
    var x = extras[e][1]
    if (x && colors.indexOf(String(x).toLowerCase()) < 0 && contrast(rgb(x), bg) >= 1.6) {
      colors.push(String(x).toLowerCase()); names.push(extras[e][0])
    }
  }
  while (colors.length < count) {
    colors.push(colors.length ? colors[colors.length % Math.max(1, chosen.length)] : "#888888")
    names.push("alpha-step")
  }
  return { colors: colors, names: names }
}
