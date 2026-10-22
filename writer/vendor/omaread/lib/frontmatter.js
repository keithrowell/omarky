.pragma library

// Front matter at the top of a file, in either of two shapes:
//
//   - YAML between fences: `---` on the first line, closed by `---` or `...`.
//   - Bare metadata (MultiMarkdown style, used by static blogs): `key: value`
//     lines from the first line, ended by the first blank line or the end of
//     the file. Keys are a single word of letters, digits, `_` and `-`; a
//     value may continue on indented lines. Two or more key lines are needed,
//     so a one-line "Note: remember this" paragraph stays prose.
//
// split() blanks those lines out of the source (so markdown-it's line map
// still matches the file) and parse() reads the small YAML subset front
// matter actually uses: scalars, quoted strings, [flow, lists], `- item`
// lists, and `>` / `|` block scalars. Anything else is kept as raw text.

var BARE_KEY = /^[A-Za-z_][A-Za-z0-9_-]*:( |$)/

function split(src) {
  var lines = String(src).split("\n").map(function(l) { return l.replace(/\r$/, "") })
  if (lines.length) lines[0] = lines[0].replace(/^\ufeff/, "")
  return fenced(lines) || bare(lines)
}

// The first `end` lines are front matter; blank them so line numbers hold.
function cut(lines, rawFrom, rawTo, end) {
  var blank = []
  for (var j = 0; j < end; j++) blank.push("")
  return { raw: lines.slice(rawFrom, rawTo).join("\n"), end: end, body: blank.concat(lines.slice(end)).join("\n") }
}

function fenced(lines) {
  if (lines[0] !== "---") return null
  for (var i = 1; i < lines.length; i++) {
    if (lines[i] === "---" || lines[i] === "...") return cut(lines, 1, i, i + 1)
  }
  return null
}

function bare(lines) {
  var keys = 0, i = 0
  for (; i < lines.length && lines[i].trim() !== ""; i++) {
    if (BARE_KEY.test(lines[i])) keys++
    else if (!(keys && /^\s/.test(lines[i]))) return null
  }
  if (keys < 2) return null
  // Through the blank line that ends the block, or to the end of the file.
  var end = Math.min(i + 1, lines.length)
  return cut(lines, 0, i, end)
}

function unquote(v) {
  v = v.trim()
  if (v.length >= 2 && (v[0] === '"' && v[v.length - 1] === '"' || v[0] === "'" && v[v.length - 1] === "'"))
    return v.slice(1, -1)
  return v.replace(/\s+#.*$/, "")
}

function flowList(v) {
  var inner = v.trim().slice(1, -1)
  var out = [], cur = "", quote = ""
  for (var i = 0; i < inner.length; i++) {
    var c = inner[i]
    if (quote) { if (c === quote) quote = ""; cur += c; continue }
    if (c === '"' || c === "'") { quote = c; cur += c; continue }
    if (c === ",") { out.push(unquote(cur)); cur = ""; continue }
    cur += c
  }
  if (cur.trim()) out.push(unquote(cur))
  return out.filter(function(s) { return s !== "" })
}

function indentOf(line) { return line.match(/^ */)[0].length }

// -> [{ key, value, items }] in file order; items is an array for lists.
function parse(raw) {
  var lines = String(raw).split("\n").map(function(l) { return l.replace(/\r$/, "") })
  var out = []
  var i = 0
  while (i < lines.length) {
    var line = lines[i]
    var m = line.match(/^([A-Za-z0-9_][A-Za-z0-9_ .-]*?)\s*:(?:\s+(.*))?$/)
    if (!m || indentOf(line) > 0) { i++; continue }
    var key = m[1], rest = (m[2] || "").trim()
    i++
    // Indented continuation lines belong to this key.
    var body = []
    while (i < lines.length && (lines[i].trim() === "" || indentOf(lines[i]) > 0 || /^- /.test(lines[i]))) {
      if (/^[A-Za-z0-9_]/.test(lines[i])) break
      body.push(lines[i])
      i++
    }
    while (body.length && body[body.length - 1].trim() === "") body.pop()

    if (/^[>|][+-]?$/.test(rest)) {
      var text = body.map(function(l) { return l.trim() })
      var value = rest[0] === "|" ? text.join("\n")
        : text.join("\n").replace(/([^\n])\n(?=[^\n])/g, "$1 ").replace(/\n\n/g, "\n")
      out.push({ key: key, value: value, items: null })
    } else if (rest === "" && body.length && body.every(function(l) { return l.trim() === "" || /^\s*- /.test(l) })) {
      out.push({ key: key, value: "", items: body.filter(function(l) { return l.trim() }).map(function(l) {
        return unquote(l.replace(/^\s*- /, ""))
      }) })
    } else if (rest === "") {
      out.push({ key: key, value: body.map(function(l) { return l.trim() }).join(", "), items: null })
    } else if (rest[0] === "[" && rest[rest.length - 1] === "]") {
      out.push({ key: key, value: "", items: flowList(rest) })
    } else {
      var v = unquote(rest)
      if (body.length) v += " " + body.map(function(l) { return l.trim() }).join(" ")
      out.push({ key: key, value: v, items: null })
    }
  }
  return out
}
