.pragma library
.import "markdown.js" as Markdown
.import "inline.js" as Inline
.import "frontmatter.js" as FrontMatter

// markdown-it tokens -> a flat array of block objects (docs/spec.md §4).
//
// build(src) -> { blocks, headings, lineCount }
//
// Every block has `type`, `srcStart` and `srcEnd` (0-based source lines,
// end exclusive, from token.map). Nested structure (list items, quotes,
// alerts, footnotes) lives inside the block as child `blocks` arrays, so
// the document view stays one flat ListView row per top-level block.
//
//   frontmatter  { title, fields: [{ key, kind: pill|list|link|text, value, items }] }
//   heading      { level, runs, text, slug }
//   paragraph    { runs }
//   list         { ordered, start, tight, depth, tasks, items: [{ number, task: ""|todo|done, blocks }] }
//   quote        { blocks }
//   alert        { kind: note|tip|important|warning|caution, title, blocks }
//   code         { lang, text, lineCount }
//   diff         { lang, text, lines: [{ kind: meta|hunk|add|del|ctx, sign, text }], added, removed }
//   table        { aligns, header: [runs], rows: [[runs]], numeric: [bool] }
//   hr           {}
//   image        { src, alt, title }
//   html         { text }            raw HTML, shown literally (comments are dropped)
//   footnotes    { items: [{ number, label, anchor, refs, blocks }] }

var ALERTS = { NOTE: "Note", TIP: "Tip", IMPORTANT: "Important", WARNING: "Warning", CAUTION: "Caution" }

function lineMap(tok) {
  var m = tok && tok.map
  return m ? { srcStart: m[0], srcEnd: m[1] } : null
}

function withMap(block, tok) {
  var m = lineMap(tok)
  block.srcStart = m ? m.srcStart : -1
  block.srcEnd = m ? m.srcEnd : -1
  return block
}

// Blocks nested inside a structure inherit a line map from their parent
// when markdown-it gives them none.
function fillMaps(blocks, start, end) {
  for (var i = 0; i < blocks.length; i++) {
    if (blocks[i].srcStart < 0) { blocks[i].srcStart = start; blocks[i].srcEnd = end }
  }
}

function Walker(tokens, env) {
  this.t = tokens
  this.i = 0
  this.env = env
  this.footnoteDefs = {}
}

// Collect blocks until `stop` (the matching close token, consumed).
function collect(w, stop, ctx) {
  var out = []
  while (w.i < w.t.length) {
    if (stop && w.t[w.i].type === stop) { w.i++; break }
    var b = one(w, ctx)
    if (b) out.push(b)
  }
  return out
}

function onlyImage(children) {
  var img = null
  for (var i = 0; i < children.length; i++) {
    var c = children[i]
    if (c.type === "image") { if (img) return null; img = c }
    else if (c.type === "softbreak" || (c.type === "text" && !c.content.trim())) continue
    else return null
  }
  return img
}

function paragraph(w, ctx) {
  var open = w.t[w.i], inline = w.t[w.i + 1]
  w.i += 3
  var children = inline && inline.children ? inline.children : []
  var img = onlyImage(children)
  if (img) {
    return withMap({ type: "image", src: img.attrGet("src") || "", alt: img.content || "", title: img.attrGet("title") || "" }, open)
  }
  return withMap({ type: "paragraph", runs: Inline.runs(children) }, open)
}

function heading(w) {
  var open = w.t[w.i], inline = w.t[w.i + 1]
  w.i += 3
  var runs = Inline.runs(inline && inline.children ? inline.children : [])
  return withMap({ type: "heading", level: Number(open.tag.slice(1)) || 1, runs: runs, text: Inline.plain(runs).trim(), slug: "" }, open)
}

function taskOf(item) {
  var first = item.blocks[0]
  if (!first || first.type !== "paragraph" || !first.runs.length) return ""
  var r = first.runs[0]
  if (r.code || r.raw || r.href) return ""
  var m = r.t.match(/^\[([ xX])\](?:\s+|$)/)
  if (!m) return ""
  r.t = r.t.slice(m[0].length)
  if (!r.t) first.runs.shift()
  return m[1] === " " ? "todo" : "done"
}

function list(w, ctx) {
  var open = w.t[w.i]
  var ordered = open.type === "ordered_list_open"
  var close = ordered ? "ordered_list_close" : "bullet_list_close"
  var start = ordered ? Number(open.attrGet("start")) || 1 : 1
  var depth = ctx.listDepth || 0
  var tight = true
  w.i++
  var items = []
  while (w.i < w.t.length && w.t[w.i].type !== close) {
    var tok = w.t[w.i]
    if (tok.type !== "list_item_open") { w.i++; continue }
    // markdown-it hides the paragraphs of tight lists.
    for (var j = w.i + 1; j < w.t.length && w.t[j].level > tok.level; j++) {
      if (w.t[j].type === "paragraph_open" && w.t[j].level === tok.level + 1 && !w.t[j].hidden) tight = false
    }
    w.i++
    var number = ordered ? (Number(tok.info) || start + items.length) : 0
    var blocks = collect(w, "list_item_close", { listDepth: depth + 1, inList: true })
    var m = lineMap(tok)
    if (m) fillMaps(blocks, m.srcStart, m.srcEnd)
    var item = { number: number, task: "", blocks: blocks }
    item.task = taskOf(item)
    items.push(item)
  }
  w.i++
  var tasks = items.some(function(it) { return it.task !== "" })
  return withMap({ type: "list", ordered: ordered, start: start, tight: tight, depth: depth, tasks: tasks, items: items }, open)
}

// `> [!NOTE]` alone on the first line of a quote turns it into an alert.
function alertOf(blocks) {
  var first = blocks[0]
  if (!first || first.type !== "paragraph") return null
  var line = "", n = 0
  for (; n < first.runs.length; n++) {
    var r = first.runs[n]
    if (r.soft || r.br) break
    if (r.code || r.href || r.raw) return null
    line += r.t
  }
  var m = line.trim().match(/^\[!([A-Za-z]+)\]$/)
  if (!m || !ALERTS[m[1].toUpperCase()]) return null
  var kind = m[1].toUpperCase()
  first.runs = first.runs.slice(n + 1)
  if (!first.runs.length) blocks.shift()
  return { kind: kind.toLowerCase(), title: ALERTS[kind] }
}

function quote(w, ctx) {
  var open = w.t[w.i]
  w.i++
  var blocks = collect(w, "blockquote_close", { listDepth: 0, inQuote: true })
  var m = lineMap(open)
  if (m) fillMaps(blocks, m.srcStart, m.srcEnd)
  var alert = alertOf(blocks)
  if (alert) return withMap({ type: "alert", kind: alert.kind, title: alert.title, blocks: blocks }, open)
  return withMap({ type: "quote", blocks: blocks }, open)
}

function diffLines(text) {
  var lines = text.split("\n"), out = [], added = 0, removed = 0
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i]
    var kind = "ctx", sign = " ", body = l
    if (/^(diff |index |--- |\+\+\+ |new file|deleted file|similarity|rename |old mode|new mode|Binary files)/.test(l)) {
      kind = "meta"; sign = ""
    } else if (/^@@/.test(l)) {
      kind = "hunk"; sign = ""
    } else if (l[0] === "+") {
      kind = "add"; sign = "+"; body = l.slice(1); added++
    } else if (l[0] === "-") {
      kind = "del"; sign = "−"; body = l.slice(1); removed++
    } else if (l[0] === " ") {
      body = l.slice(1)
    } else if (l[0] === "\\") {
      kind = "meta"; sign = ""
    }
    out.push({ kind: kind, sign: sign, text: body })
  }
  return { lines: out, added: added, removed: removed }
}

function code(w) {
  var tok = w.t[w.i]
  w.i++
  var info = (tok.info || "").trim()
  var lang = info ? info.split(/\s+/)[0] : ""
  var text = tok.content.replace(/\n$/, "")
  var low = lang.toLowerCase()
  if (low === "diff" || low === "patch" || low === "udiff") {
    var d = diffLines(text)
    return withMap({ type: "diff", lang: lang, text: text, lines: d.lines, added: d.added, removed: d.removed }, tok)
  }
  return withMap({ type: "code", lang: lang, text: text, lineCount: text ? text.split("\n").length : 0 }, tok)
}

var NUMERIC = /^[-+−]?[$€£¥]?\d[\d,]*(\.\d+)?(%|:\d+(\.\d+)?|[kKmMbBx]|ms|s|h)?$/

function table(w) {
  var open = w.t[w.i]
  w.i++
  var aligns = [], header = [], rows = [], row = null, inHead = false
  while (w.i < w.t.length && w.t[w.i].type !== "table_close") {
    var t = w.t[w.i]
    if (t.type === "thead_open") inHead = true
    else if (t.type === "thead_close") inHead = false
    else if (t.type === "tr_open") row = []
    else if (t.type === "tr_close") { if (!inHead && row) rows.push(row); row = null }
    else if (t.type === "th_open" || t.type === "td_open") {
      var style = t.attrGet("style") || ""
      var a = style.match(/text-align:(\w+)/)
      if (inHead) aligns.push(a ? a[1] : "")
      var inline = w.t[w.i + 1]
      var runs = inline && inline.type === "inline" ? Inline.runs(inline.children || []) : []
      if (inHead) header.push(runs)
      else if (row) row.push(runs)
    }
    w.i++
  }
  w.i++
  var cols = header.length
  for (var r = 0; r < rows.length; r++) {
    while (rows[r].length < cols) rows[r].push([])
    if (rows[r].length > cols) rows[r] = rows[r].slice(0, cols)
  }
  var numeric = []
  for (var c = 0; c < cols; c++) {
    var any = false, all = true
    for (var k = 0; k < rows.length; k++) {
      var cell = Inline.plain(rows[k][c]).trim()
      if (!cell) continue
      any = true
      if (!NUMERIC.test(cell)) { all = false; break }
    }
    numeric.push(any && all)
  }
  return withMap({ type: "table", aligns: aligns, header: header, rows: rows, numeric: numeric }, open)
}

function html(w) {
  var tok = w.t[w.i]
  w.i++
  var text = tok.content.replace(/\s+$/, "")
  // Comments (Agentile's SNAPSHOT headers among them) vanish; an unclosed
  // one would swallow the rest of the file, so it stays visible instead.
  if (/^(\s*<!--[\s\S]*?-->\s*)+$/.test(text)) return null
  return withMap({ type: "html", text: text }, tok)
}

function footnoteDef(w) {
  var open = w.t[w.i]
  w.i++
  var blocks = collect(w, "footnote_reference_close", { listDepth: 0 })
  var m = lineMap(open)
  if (m) fillMaps(blocks, m.srcStart, m.srcEnd)
  var label = open.meta.label
  if (!w.footnoteDefs[label]) w.footnoteDefs[label] = { blocks: blocks, map: m, order: Object.keys(w.footnoteDefs).length }
  return null
}

function one(w, ctx) {
  var t = w.t[w.i]
  switch (t.type) {
  case "paragraph_open": return paragraph(w, ctx)
  case "heading_open": return heading(w)
  case "bullet_list_open":
  case "ordered_list_open": return list(w, ctx)
  case "blockquote_open": return quote(w, ctx)
  case "fence":
  case "code_block": return code(w)
  case "table_open": return table(w)
  case "hr": w.i++; return withMap({ type: "hr" }, t)
  case "html_block": return html(w)
  case "footnote_reference_open": return footnoteDef(w)
  default: w.i++; return null
  }
}

// GitHub's heading anchors: lower case, punctuation and symbols dropped,
// each space a hyphen, repeats numbered -1, -2, ...
function slugify(text) {
  return String(text).toLowerCase()
    .replace(/[\u0000-\u001F!-,.\/:-@\[-\^`{-~¡-¿×÷ -⁯←-⯿　-〿\uD800-\uDFFF︀-️]/g, "")
    .replace(/ /g, "-")
}

function footnotesBlock(w, env) {
  var defs = w.footnoteDefs
  var labels = Object.keys(defs)
  if (!labels.length) return null
  var list = (env.footnotes && env.footnotes.list) || []
  var items = [], used = {}
  for (var i = 0; i < list.length; i++) {
    if (!list[i] || !defs[list[i].label]) continue
    used[list[i].label] = true
    items.push({ label: list[i].label, refs: list[i].count, blocks: defs[list[i].label].blocks, map: defs[list[i].label].map })
  }
  labels.sort(function(a, b) { return defs[a].order - defs[b].order })
  labels.forEach(function(l) {
    if (!used[l]) items.push({ label: l, refs: 0, blocks: defs[l].blocks, map: defs[l].map })
  })
  var start = Infinity, end = 0
  items.forEach(function(it, k) {
    it.number = k + 1
    it.anchor = "fn-" + it.number
    if (it.map) { start = Math.min(start, it.map.srcStart); end = Math.max(end, it.map.srcEnd) }
    delete it.map
  })
  return { type: "footnotes", items: items, srcStart: start === Infinity ? 0 : start, srcEnd: end }
}

function build(src) {
  src = src === null || src === undefined ? "" : String(src)
  var lineCount = src.split("\n").length
  var fm = FrontMatter.split(src)
  var body = fm ? fm.body : src
  var env = {}
  var tokens = Markdown.parse(body, env)
  var w = new Walker(tokens, env)
  var blocks = collect(w, null, { listDepth: 0 })

  if (fm) {
    var fields = FrontMatter.parse(fm.raw), title = ""
    var rows = []
    fields.forEach(function(f) {
      if (f.key.toLowerCase() === "title" && !f.items && !title) { title = f.value; return }
      var kind = f.items ? "list"
        : /^(https?:\/\/|mailto:)\S+$/.test(f.value) ? "link"
        : f.value.length <= 32 && f.value.split(/\s+/).length <= 4 ? "pill"
        : "text"
      rows.push({ key: f.key, kind: kind, value: f.value, items: f.items || [] })
    })
    blocks.unshift({ type: "frontmatter", title: title, fields: rows, srcStart: 0, srcEnd: fm.end })
  }

  // Footnote numbers follow the order of first citation; renumber refs.
  var notes = footnotesBlock(w, env)
  if (notes) blocks.push(notes)

  var seen = {}, headings = []
  for (var i = 0; i < blocks.length; i++) {
    var b = blocks[i]
    if (b.type !== "heading") continue
    var base = slugify(b.text)
    var n = seen[base] || 0
    seen[base] = n + 1
    b.slug = n ? base + "-" + n : base
    headings.push({ level: b.level, text: b.text, slug: b.slug, index: i, srcStart: b.srcStart })
  }
  return { blocks: blocks, headings: headings, lineCount: lineCount, anchors: anchors(blocks), pieces: stampPieces(blocks) }
}

// Anchor name -> top-level block index: heading slugs, footnotes (fn-N)
// and the places they are cited from (fnref-N-M).
function anchors(blocks) {
  var out = {}
  function refs(list, index) {
    for (var i = 0; i < list.length; i++) {
      var b = list[i]
      var runSets = b.runs ? [b.runs] : b.type === "table" ? b.header.concat([].concat.apply([], b.rows)) : []
      runSets.forEach(function(rs) {
        rs.forEach(function(r) { if (r.anchor && !(r.anchor in out)) out[r.anchor] = index })
      })
      if (b.blocks) refs(b.blocks, index)
      if (b.items && b.type === "list") b.items.forEach(function(it) { refs(it.blocks, index) })
    }
  }
  for (var i = 0; i < blocks.length; i++) {
    var b = blocks[i]
    if (b.type === "heading" && !(b.slug in out)) out[b.slug] = i
    if (b.type === "footnotes") b.items.forEach(function(it) { out[it.anchor] = i })
    else refs([b], i)
  }
  return out
}

// Give every searchable piece of text a document-order id (pid) and return
// [{ pid, block, text }]: what find matches against. A rendered text item
// compares its pid with the current match to know whether to emphasise it.
function stampPieces(blocks) {
  var out = []
  function add(text, top) { out.push({ pid: out.length, block: top, text: text }); return out.length - 1 }
  function walk(b, top) {
    switch (b.type) {
    case "paragraph":
    case "heading": b.pid = add(Inline.plain(b.runs), top); break
    case "code":
    case "diff": b.pid = add(b.text, top); break
    case "list": b.items.forEach(function(it) { it.blocks.forEach(function(c) { walk(c, top) }) }); break
    case "quote":
    case "alert": b.blocks.forEach(function(c) { walk(c, top) }); break
    case "footnotes": b.items.forEach(function(it) { it.blocks.forEach(function(c) { walk(c, top) }) }); break
    case "table":
      b.headerPids = b.header.map(function(c) { return add(Inline.plain(c), top) })
      b.rowPids = b.rows.map(function(r) { return r.map(function(c) { return add(Inline.plain(c), top) }) })
      break
    }
  }
  for (var i = 0; i < blocks.length; i++) walk(blocks[i], i)
  return out
}

// Every match of q, in document order: [{ pid, block, k }] where k counts
// matches within that piece.
function findAll(doc, q) {
  var out = []
  if (!q) return out
  var needle = String(q).toLowerCase()
  for (var i = 0; i < doc.pieces.length; i++) {
    var p = doc.pieces[i]
    var hay = p.text.toLowerCase(), at = hay.indexOf(needle), k = 0
    while (at >= 0) {
      out.push({ pid: p.pid, block: p.block, k: k++ })
      at = hay.indexOf(needle, at + needle.length)
    }
  }
  return out
}
