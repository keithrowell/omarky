.pragma library
.import "blocks.js" as Blocks

// What a rewrite works on: a run of the source text, as character offsets.
// Pure, so tst_ranges.qml tests it without a window.
//
// lineStarts(text)                 -> the offset each line starts at
// blockAt(text, pos)               -> { start, end, kind: "block" } the top-level block around pos
// sectionAt(text, pos)             -> { start, end, kind: "section" } the heading's section around pos
// words(text, a, b)                -> { start, end, kind: "selection" } a selection widened to whole words
// widen(text, range, pos)          -> the next larger range: selection, block, section, outer section, document
// locate(text, original, near)     -> where `original` now starts, nearest `near`, or -1
//
// A range never takes the newline that ends its last line, so replacing it
// keeps the blank lines between blocks as they were.

function lineStarts(text) {
  var out = [0]
  for (var i = 0; i < text.length; i++) if (text.charCodeAt(i) === 10) out.push(i + 1)
  return out
}

// [first line, end line) as offsets, without the last line's newline.
function span(text, starts, first, endLine) {
  var a = starts[Math.max(0, Math.min(first, starts.length - 1))]
  var b = endLine >= starts.length ? text.length : starts[endLine] - 1
  return { start: a, end: Math.max(a, b) }
}

// Blank lines after a block (a list's map takes one) stay outside.
function trimEnd(text, r) {
  while (r.end > r.start && /\s/.test(text.charAt(r.end - 1))) r.end--
  return r
}

function lineOf(starts, pos) {
  var lo = 0, hi = starts.length - 1
  while (lo < hi) {
    var mid = (lo + hi + 1) >> 1
    if (starts[mid] <= pos) lo = mid
    else hi = mid - 1
  }
  return lo
}

function topBlocks(text) {
  return Blocks.build(text).blocks.filter(function(b) { return b.srcStart >= 0 && b.srcEnd > b.srcStart })
}

// The block holding the cursor's line; on a blank line, the next block, or
// the last one when the cursor is past them all.
function blockAt(text, pos) {
  var starts = lineStarts(text), line = lineOf(starts, pos)
  var bs = topBlocks(text)
  if (bs.length === 0) return { start: 0, end: text.length, kind: "block" }
  var pick = null
  for (var i = 0; i < bs.length; i++) {
    if (bs[i].srcStart <= line && line < bs[i].srcEnd) { pick = bs[i]; break }
    if (bs[i].srcStart > line) { pick = bs[i]; break }
  }
  if (!pick) pick = bs[bs.length - 1]
  var r = trimEnd(text, span(text, starts, pick.srcStart, pick.srcEnd))
  r.kind = "block"
  return r
}

// From the heading at or above `pos` to the next heading of the same or a
// higher level. `atLeast` (a level) skips headings deeper than it, which
// is how widen() climbs to the outer section. Before the first heading,
// the text up to it.
function sectionAt(text, pos, atLeast) {
  var starts = lineStarts(text), line = lineOf(starts, pos)
  var hs = topBlocks(text).filter(function(b) { return b.type === "heading" && (!atLeast || b.level <= atLeast) })
  var cur = -1
  for (var i = 0; i < hs.length; i++) { if (hs[i].srcStart <= line) cur = i; else break }
  var r
  if (cur < 0) {
    r = span(text, starts, 0, hs.length ? hs[0].srcStart : starts.length)
  } else {
    var endLine = starts.length
    for (var k = cur + 1; k < hs.length; k++) if (hs[k].level <= hs[cur].level) { endLine = hs[k].srcStart; break }
    r = span(text, starts, hs[cur].srcStart, endLine)
    r.level = hs[cur].level
  }
  r = trimEnd(text, r)
  r.kind = "section"
  return r
}

var WORDCH = /[A-Za-z0-9À-ɏͰ-ϿЀ-ӿ'’_*`~\]\)]/

function words(text, a, b) {
  if (a > b) { var t = a; a = b; b = t }
  while (a > 0 && WORDCH.test(text.charAt(a - 1)) && WORDCH.test(text.charAt(a))) a--
  while (b < text.length && WORDCH.test(text.charAt(b - 1)) && WORDCH.test(text.charAt(b))) b++
  return { start: a, end: b, kind: "selection" }
}

function contains(outer, inner) { return outer.start <= inner.start && outer.end >= inner.end }
function same(x, y) { return x.start === y.start && x.end === y.end }

function widen(text, range, pos) {
  var whole = { start: 0, end: text.length, kind: "document" }
  if (range.kind === "document") return whole
  var p = pos === undefined ? range.start : pos
  var steps = []
  if (range.kind === "selection") steps.push(blockAt(text, p))
  if (range.kind === "selection" || range.kind === "block") steps.push(sectionAt(text, p))
  var sec = range.kind === "section" ? range : sectionAt(text, p)
  for (var lvl = (sec.level || 1) - 1; lvl >= 1; lvl--) steps.push(sectionAt(text, p, lvl))
  steps.push(whole)
  for (var i = 0; i < steps.length; i++)
    if (contains(steps[i], range) && !same(steps[i], range)) return steps[i]
  return whole
}

function locate(text, original, near) {
  if (original === "") return -1
  if (text.substr(near, original.length) === original) return near
  var best = -1, at = text.indexOf(original)
  while (at >= 0) {
    if (best < 0 || Math.abs(at - near) < Math.abs(best - near)) best = at
    at = text.indexOf(original, at + 1)
  }
  return best
}
