.pragma library

// Colours derived from the theme that need a rule, not just a lookup.
//
// Links are drawn in the accent, but a theme may make its accent the same
// colour as its text (Kanagawa does), and then a link is invisible as one.
// linkColor() keeps the accent unless it is within CLOSE of the text colour
// in RGB, and falls back to the theme's blue. CLOSE is well under the
// distance of any installed theme whose accent is merely subtle (about 42).

var CLOSE = 24

function rgb(hex) {
  var h = String(hex).trim().replace(/^#/, "")
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]
}

function norm(hex) { return "#" + String(hex).trim().replace(/^#/, "").slice(0, 6).toLowerCase() }

function distance(a, b) {
  var p = rgb(a), q = rgb(b)
  return Math.sqrt((p[0] - q[0]) * (p[0] - q[0]) + (p[1] - q[1]) * (p[1] - q[1]) + (p[2] - q[2]) * (p[2] - q[2]))
}

function linkColor(accent, text, blue) {
  return distance(accent, text) < CLOSE ? norm(blue) : norm(accent)
}
