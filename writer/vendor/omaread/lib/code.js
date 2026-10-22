.pragma library

// Code -> Qt rich text: one paragraph per source line, so a fixed line
// height applies and KSyntaxHighlighting still sees one block per line.

function esc(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// An empty paragraph would be dropped by Qt's HTML import, taking the blank
// line with it; a no-break space keeps it (and copies as a space).
function lineHtml(line, lineHeight, extra, body) {
  return "<p style=\"line-height:" + lineHeight + "px; margin:0; white-space:pre" + (extra || "") + "\">" +
         (body !== undefined ? body : line ? esc(line) : "&nbsp;") + "</p>"
}

// One line with find matches painted; `state.k` counts matches across the
// whole block so the current one (opts.current) can be told apart.
function paintLine(line, opts, state) {
  if (!opts || !opts.find || !line) return line ? esc(line) : "&nbsp;"
  var hay = line.toLowerCase(), needle = String(opts.find).toLowerCase()
  var out = "", pos = 0, at = hay.indexOf(needle)
  while (at >= 0) {
    var bg = state.k === opts.current ? opts.currentBg : opts.findBg
    var fg = state.k === opts.current && opts.currentText ? "; color:" + opts.currentText : ""
    out += esc(line.slice(pos, at)) + "<span style=\"background-color:" + bg + fg + "\">" + esc(line.slice(at, at + needle.length)) + "</span>"
    pos = at + needle.length
    state.k++
    at = hay.indexOf(needle, pos)
  }
  return out + esc(line.slice(pos))
}

// opts (optional): { find, findBg, current, currentBg, currentText }
function toHtml(text, lineHeight, opts) {
  var lines = String(text).split("\n")
  var out = "", state = { k: 0 }
  for (var i = 0; i < lines.length; i++) out += lineHtml(lines[i], lineHeight, "", paintLine(lines[i], opts, state))
  return out
}

// The line holding match number k of q (for scrolling to it), or -1.
function lineOfMatch(text, q, k) {
  if (!q) return -1
  var lines = String(text).split("\n"), needle = String(q).toLowerCase(), seen = 0
  for (var i = 0; i < lines.length; i++) {
    var hay = lines[i].toLowerCase(), at = hay.indexOf(needle)
    while (at >= 0) {
      if (seen === k) return i
      seen++
      at = hay.indexOf(needle, at + needle.length)
    }
  }
  return -1
}

// "1\n2\n…" right-aligned by the view.
function gutter(count, lineHeight) {
  var out = ""
  for (var i = 1; i <= count; i++) out += "<p align=\"right\" style=\"line-height:" + lineHeight + "px; margin:0\">" + i + "</p>"
  return out
}

// Document position of match k of q, as laid out by toHtml(): each line is
// a paragraph (one separator character) and an empty line holds one space.
function docPosOfMatch(text, q, k) {
  if (!q) return -1
  var lines = String(text).split("\n"), needle = String(q).toLowerCase(), seen = 0, base = 0
  for (var i = 0; i < lines.length; i++) {
    var hay = lines[i].toLowerCase(), at = hay.indexOf(needle)
    while (at >= 0) {
      if (seen === k) return base + at
      seen++
      at = hay.indexOf(needle, at + needle.length)
    }
    base += Math.max(1, lines[i].length) + 1
  }
  return -1
}
