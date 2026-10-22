.pragma library

// The editor's text logic, kept pure so it can be tested without a window
// (ui/test/tst_editing.qml). Every function takes plain strings and
// positions and returns what to change; Editor.qml applies it.

var LIST = /^(\s*)([-*+]|(\d{1,9})([.)]))(\s+)(\[[ xX]\]\s+)?/
var QUOTE = /^((?: {0,3}>[ ]?)+)/
// Letters V4 can match (it has no \p{L}): Latin, Greek, Cyrillic.
var L = "A-Za-z\u00C0-\u024F\u1E00-\u1EFF\u0370-\u03FF\u0400-\u04FF"
var WORD = new RegExp("[" + L + "0-9][" + L + "0-9'\u2019.-]*", "g")
var LETTER = new RegExp("[" + L + "'\u2019]")

// The line around `pos`: { start, end, text }.
function lineAt(text, pos) {
  var start = text.lastIndexOf("\n", pos - 1) + 1
  var end = text.indexOf("\n", pos)
  if (end < 0) end = text.length
  return { start: start, end: end, text: text.slice(start, end) }
}

// Enter at `pos`. Returns null for a plain newline, or
//   { start, end, insert, cursor }: replace [start, end) with `insert` and
//   put the cursor at `cursor` (absolute, after the change).
// A list item or quote carries its marker to the next line; Enter on an
// empty item removes the marker instead (ending the list).
function enter(text, pos) {
  var line = lineAt(text, pos)
  var before = line.text.slice(0, pos - line.start)
  var m = LIST.exec(line.text)
  if (m && pos - line.start >= m[0].length) {
    var rest = line.text.slice(m[0].length)
    if (rest.trim() === "" && before.length === line.text.length)
      return { start: line.start, end: line.end, insert: "", cursor: line.start }
    var marker = m[2]
    if (m[3] !== undefined) marker = (parseInt(m[3], 10) + 1) + m[4]
    var box = m[6] ? "[ ] " : ""
    var ins = "\n" + m[1] + marker + m[5] + box
    return { start: pos, end: pos, insert: ins, cursor: pos + ins.length }
  }
  var q = QUOTE.exec(line.text)
  if (q && pos - line.start >= q[0].length) {
    if (line.text.slice(q[0].length).trim() === "")
      return { start: line.start, end: line.end, insert: "", cursor: line.start }
    var qi = "\n" + q[1]
    return { start: pos, end: pos, insert: qi, cursor: pos + qi.length }
  }
  return null
}

// Tab (out = false) or Shift+Tab (out = true) on a list item: indent by
// the marker's width, or back. Returns null when the line is not a list.
function indent(text, pos, out) {
  var line = lineAt(text, pos)
  var m = LIST.exec(line.text)
  if (!m) return null
  var step = m[2].length + m[5].length
  if (m[3] === undefined) step = 2
  if (out) {
    var lead = m[1].length
    if (lead === 0) return null
    var cut = Math.min(step, lead)
    return { start: line.start, end: line.start + cut, insert: "", cursor: Math.max(line.start, pos - cut) }
  }
  var pad = new Array(step + 1).join(" ")
  return { start: line.start, end: line.start, insert: pad, cursor: pos + pad.length }
}

// Wrap [selStart, selEnd) in `mark` (** for bold, * for italic, ` for
// code), or unwrap it when it is already wrapped. With no selection the
// marks go in and the cursor sits between them.
function wrap(text, selStart, selEnd, mark) {
  var len = mark.length
  var inner = text.slice(selStart, selEnd)
  var outside = text.slice(selStart - len, selStart) === mark && text.slice(selEnd, selEnd + len) === mark
  if (selStart !== selEnd && outside)
    return { start: selStart - len, end: selEnd + len, insert: inner, selStart: selStart - len, selEnd: selEnd - len }
  if (inner.length > 2 * len && inner.slice(0, len) === mark && inner.slice(-len) === mark) {
    var bare = inner.slice(len, -len)
    return { start: selStart, end: selEnd, insert: bare, selStart: selStart, selEnd: selStart + bare.length }
  }
  return { start: selStart, end: selEnd, insert: mark + inner + mark, selStart: selStart + len, selEnd: selEnd + len }
}

// Ctrl+K: [selection](|) with the cursor in the brackets' URL slot, or
// [|](url) when the selection is itself a URL.
function link(text, selStart, selEnd) {
  var inner = text.slice(selStart, selEnd)
  if (/^(https?:\/\/|mailto:)\S+$/.test(inner)) {
    var ins = "[](" + inner + ")"
    return { start: selStart, end: selEnd, insert: ins, selStart: selStart + 1, selEnd: selStart + 1 }
  }
  var out = "[" + inner + "]()"
  var c = selStart + out.length - 1
  return { start: selStart, end: selEnd, insert: out, selStart: c, selEnd: c }
}

// Ctrl+1..6 sets the line's heading level; Ctrl+0 (level 0) clears it.
// The same level again clears it too.
function heading(text, pos, level) {
  var line = lineAt(text, pos)
  var m = /^ {0,3}(#{1,6})[ \t]*/.exec(line.text)
  var current = m ? m[1].length : 0
  var cut = m ? m[0].length : 0
  var want = level === current ? 0 : level
  var mark = want > 0 ? new Array(want + 1).join("#") + " " : ""
  var offset = Math.max(0, pos - line.start - cut)
  return { start: line.start, end: line.start + cut, insert: mark, cursor: line.start + mark.length + offset }
}

// Words, characters and minutes to read, from Markdown source. Syntax
// marks, URLs and front matter don't count as words.
function stats(text) {
  var s = String(text || "")
  s = s.replace(/^---\n[\s\S]*?\n(---|\.\.\.)\n/, "")
  var chars = s.replace(/\s/g, "").length
  s = s.replace(/```[\s\S]*?```/g, " ")
       .replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1")
       .replace(/<[^>]+>/g, " ")
       .replace(/https?:\/\/\S+/g, " ")
       .replace(/[#>*_`~=|\[\]-]+/g, " ")
  var words = s.match(WORD)
  var n = words ? words.length : 0
  return { words: n, chars: chars, minutes: Math.max(n > 0 ? 1 : 0, Math.round(n / 230)) }
}

// The word (letters and apostrophes) around `pos`: { start, end, word },
// or null.
function wordAt(text, pos) {
  var isWord = function(ch) { return !!ch && LETTER.test(ch) }
  var a = pos, b = pos
  while (a > 0 && isWord(text.charAt(a - 1))) a--
  while (b < text.length && isWord(text.charAt(b))) b++
  while (a < b && /['’]/.test(text.charAt(a))) a++
  while (b > a && /['’]/.test(text.charAt(b - 1))) b--
  if (a === b) return null
  return { start: a, end: b, word: text.slice(a, b) }
}

// Every match of `query` (case-insensitive, literal) as start offsets.
function findAll(text, query) {
  var out = []
  if (!query) return out
  var hay = String(text).toLowerCase(), needle = String(query).toLowerCase()
  var i = hay.indexOf(needle)
  while (i >= 0 && out.length < 10000) { out.push(i); i = hay.indexOf(needle, i + needle.length) }
  return out
}

// The source line (0-based) holding `pos`.
function lineNumber(text, pos) {
  var n = 0
  for (var i = text.indexOf("\n"); i >= 0 && i < pos; i = text.indexOf("\n", i + 1)) n++
  return n
}
