.pragma library

// Code -> Qt rich text: one paragraph per source line, so a fixed line
// height applies and KSyntaxHighlighting still sees one block per line.

function esc(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// An empty paragraph would be dropped by Qt's HTML import, taking the blank
// line with it; a no-break space keeps it (and copies as a space).
function lineHtml(line, lineHeight, extra) {
  return "<p style=\"line-height:" + lineHeight + "px; margin:0; white-space:pre" + (extra || "") + "\">" + (line ? esc(line) : "&nbsp;") + "</p>"
}

function toHtml(text, lineHeight) {
  var lines = String(text).split("\n")
  var out = ""
  for (var i = 0; i < lines.length; i++) out += lineHtml(lines[i], lineHeight)
  return out
}

// "1\n2\n…" right-aligned by the view.
function gutter(count, lineHeight) {
  var out = ""
  for (var i = 1; i <= count; i++) out += "<p align=\"right\" style=\"line-height:" + lineHeight + "px; margin:0\">" + i + "</p>"
  return out
}
