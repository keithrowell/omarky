.pragma library

// YAML front matter: a `---` fence on the first line, closed by `---` or
// `...`. split() blanks those lines out of the source (so markdown-it's line
// map still matches the file) and parse() reads the small YAML subset front
// matter actually uses: scalars, quoted strings, [flow, lists], `- item`
// lists, and `>` / `|` block scalars. Anything else is kept as raw text.

function split(src) {
  var lines = String(src).split("\n")
  var first = lines[0].replace(/^﻿/, "").replace(/\r$/, "")
  if (first !== "---") return null
  for (var i = 1; i < lines.length; i++) {
    var l = lines[i].replace(/\r$/, "")
    if (l === "---" || l === "...") {
      var raw = lines.slice(1, i).join("\n")
      var blank = []
      for (var j = 0; j <= i; j++) blank.push("")
      return { raw: raw, end: i + 1, body: blank.concat(lines.slice(i + 1)).join("\n") }
    }
  }
  return null
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
