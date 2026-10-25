.pragma library
.import "../blocks.js" as Blocks
.import "../inline.js" as Inline
.import "words.js" as Words
.import "runs.js" as Runs
.import "align.js" as Align

// Two Markdown texts -> the new document's blocks with change marks.
//
// compare(fromText, toText) -> { blocks, total, lineCount, source }
// document(result)          -> what MarkdownView.changes takes
// changedIndices(blocks)    -> top-level indices that changed
//
// Every top-level block carries `change` (same|added|removed|reworded) and
// `changes` (its count: 1, or the number of changed items for a list);
// list items carry `change`; headings carry `sectionChanges`, the count
// over their section and its subsections. Removed blocks sit where they
// stood relative to their neighbours, every run flagged `del`, with
// srcStart and srcEnd set to the line of the block that follows them.

var SECTION_SIM = 0.6, BLOCK_SIM = 0.5

function plainOf(b) {
  switch (b.type) {
  case "paragraph": case "heading": return Inline.plain(b.runs)
  case "code": case "diff": return b.text
  case "list": return b.items.map(function(it) { return it.blocks.map(plainOf).join("\n") }).join("\n")
  case "quote": case "alert": return b.blocks.map(plainOf).join("\n")
  case "table": return b.header.map(Inline.plain).join("|") + "\n" + b.rows.map(function(r) { return r.map(Inline.plain).join("|") }).join("\n")
  case "image": return b.src + " " + b.alt
  case "gallery": return b.items.map(function(i) { return i.src }).join(" ")
  case "html": return b.text
  case "frontmatter": return b.title + "\n" + b.fields.map(function(f) { return f.key + ": " + f.value + (f.items || []).join(",") }).join("\n")
  case "footnotes": return b.items.map(function(it) { return it.label + " " + it.blocks.map(plainOf).join("\n") }).join("\n")
  default: return ""
  }
}

function norm(s) { return String(s).replace(/\s+/g, " ").trim() }
function keyOf(b) { return b.type + "\u0001" + norm(plainOf(b)) }

function clone(b) {
  var o = {}
  for (var k in b) o[k] = b[k]
  return o
}

// A block marked whole. The view marks a list by its items, so a list's
// items (nested lists included) carry the same change.
function mark(b, change) {
  var c = clone(b)
  c.change = change
  c.changes = change === "same" ? 0 : 1
  if (c.type === "list") c.items = c.items.map(function(it) { return stampItem(it, change) })
  return c
}

function stampItem(it, change) {
  var i2 = clone(it)
  i2.change = change
  i2.blocks = it.blocks.map(function(x) { return x.type === "list" ? mark(x, change) : x })
  return i2
}

// Every run in a block (and its children) flagged `kind`. A removed code
// block becomes a diff of deleted lines.
function flagAll(b, kind) {
  var c = clone(b)
  if (c.runs) c.runs = Runs.markAll(c.runs, kind)
  if (c.blocks) c.blocks = c.blocks.map(function(x) { return flagAll(x, kind) })
  if (c.items && c.type !== "gallery") c.items = c.items.map(function(it) {
    var i2 = clone(it)
    if (i2.blocks) i2.blocks = i2.blocks.map(function(x) { return flagAll(x, kind) })
    if (c.type === "list") i2.change = kind === "del" ? "removed" : "added"
    return i2
  })
  if (c.type === "table") {
    c.header = c.header.map(function(r) { return Runs.markAll(r, kind) })
    c.rows = c.rows.map(function(row) { return row.map(function(r) { return Runs.markAll(r, kind) }) })
  }
  if (c.type === "code" && kind === "del") return codeAsDiff(c, c.text.split("\n").map(function(l) { return { kind: "del", text: l } }))
  return c
}

function codeAsDiff(code, lines) {
  var added = 0, removed = 0
  lines.forEach(function(l) { if (l.kind === "add") added++; else if (l.kind === "del") removed++ })
  return { type: "diff", lang: code.lang || "", text: lines.map(function(l) { return l.text }).join("\n"),
           lines: lines.map(function(l) { return { kind: l.kind, sign: l.kind === "add" ? "+" : l.kind === "del" ? "−" : " ", text: l.text } }),
           added: added, removed: removed, srcStart: code.srcStart, srcEnd: code.srcEnd, lineCount: lines.length }
}

function removedBlock(b, anchorLine) {
  var r = flagAll(b, "del")
  r.change = "removed"
  r.changes = 1
  if (anchorLine !== undefined && anchorLine !== null) { r.srcStart = anchorLine; r.srcEnd = anchorLine }
  return r
}

// ---- pairing two blocks of one type

function pairBlocks(a, b) {
  switch (b.type) {
  case "paragraph": case "heading": {
    var m = Runs.markRuns(a.runs, b.runs)
    var c = clone(b); c.runs = m.runs
    return finish(c, m.changed)
  }
  case "list": return pairLists(a, b)
  case "quote": case "alert": {
    var inner = mergeSequences(a.blocks, b.blocks)
    var q = clone(b); q.blocks = inner.blocks
    return finish(q, inner.total > 0, inner.total)
  }
  case "table": return pairTables(a, b)
  case "code": return pairCode(a, b)
  case "frontmatter": {
    var fm = clone(b)
    var byKey = {}
    a.fields.forEach(function(f) { byKey[f.key] = f })
    var changed = a.title !== b.title
    fm.fields = b.fields.map(function(f) {
      var old = byKey[f.key]
      var same = old && old.value === f.value && (old.items || []).join("\n") === (f.items || []).join("\n")
      if (!same) changed = true
      var g = clone(f); g.change = same ? "same" : old ? "reworded" : "added"
      return g
    })
    return finish(fm, changed)
  }
  case "footnotes": {
    var fn = clone(b)
    var items = pairItems(a.items, b.items, function(it) { return it.label })
    fn.items = items.items
    return finish(fn, items.total > 0, items.total)
  }
  default:
    return keyOf(a) === keyOf(b) ? mark(b, "same") : null
  }
}

function finish(block, changed, count) {
  block.change = changed ? "reworded" : "same"
  block.changes = changed ? (count || 1) : 0
  return block
}

function lineTokens(text) { return text.split("\n").map(function(l) { return { t: l, key: l } }) }

// Code pairs line by line into a diff block: ctx, del and add lines.
function pairCode(a, b) {
  if (a.text === b.text) return mark(b, "same")
  var al = a.text.split("\n"), bl = b.text.split("\n")
  var ops = Words.diff(lineTokens(a.text), lineTokens(b.text))
  var lines = []
  ops.forEach(function(o) {
    if (o.kind === "eq") for (var i = o.b0; i < o.b1; i++) lines.push({ kind: "ctx", text: bl[i] })
    else if (o.kind === "del") for (var j = o.a0; j < o.a1; j++) lines.push({ kind: "del", text: al[j] })
    else for (var k = o.b0; k < o.b1; k++) lines.push({ kind: "add", text: bl[k] })
  })
  return finish(codeAsDiff(b, lines), true)
}

function pairLists(a, b) {
  var items = pairItems(a.items, b.items, function(it) { return norm(it.blocks.map(plainOf).join("\n")) })
  var l = clone(b)
  l.items = items.items
  return finish(l, items.total > 0, items.total)
}

// Where each unpaired a index goes in b order: before the b index that
// follows its last paired predecessor, or after everything (-1).
function slots(aCount, bCount, pairs) {
  var byA = {}
  pairs.forEach(function(pr) { byA[pr[0]] = pr })
  var before = {}, trailing = [], nextB = 0
  for (var i = 0; i < aCount; i++) {
    if (byA[i]) { nextB = byA[i][1] + 1; continue }
    if (nextB < bCount) (before[nextB] = before[nextB] || []).push(i)
    else trailing.push(i)
  }
  return { before: before, trailing: trailing }
}

// Word bags for a list, each computed the first time it is asked for: only
// blocks left over after the exact pass ever need one.
function lazyBags(items, textOf) {
  var bags = new Array(items.length)
  return function(i) {
    if (!bags[i]) bags[i] = Words.bag(textOf(items[i]))
    return bags[i]
  }
}

// Items (list items, footnotes) aligned exactly then by similarity; each
// pair's blocks merged recursively. Removed items keep their place.
function pairItems(aItems, bItems, keyFn) {
  var bagA = lazyBags(aItems, keyFn), bagB = lazyBags(bItems, keyFn)
  var simOf = function(i, j) { return Words.dice(bagA(i), bagB(j)) }
  var p = Align.plan(aItems, bItems, keyFn, simOf, BLOCK_SIM)
  var pairByB = {}
  p.pairs.forEach(function(pr) { pairByB[pr[1]] = pr })
  var where = slots(aItems.length, bItems.length, p.pairs)
  var out = [], total = 0
  function removedItem(it) {
    var r = clone(it)
    r.blocks = it.blocks.map(function(x) { return flagAll(x, "del") })
    r.change = "removed"
    return r
  }
  for (var j = 0; j < bItems.length; j++) {
    (where.before[j] || []).forEach(function(i) { out.push(removedItem(aItems[i])); total++ })
    var it = clone(bItems[j])
    var pr = pairByB[j]
    if (!pr) { it.change = "added"; total++ }
    else if (pr[2]) it.change = "same"
    else {
      var inner = mergeSequences(aItems[pr[0]].blocks, bItems[j].blocks)
      it.blocks = inner.blocks
      it.change = inner.total > 0 ? "reworded" : "same"
      if (inner.total > 0) total++
    }
    out.push(it)
  }
  where.trailing.forEach(function(i) { out.push(removedItem(aItems[i])); total++ })
  return { items: out, total: total }
}

// Rows align by first cell, then by similarity over the whole row; cells
// take the word diff. Removed rows stay, struck, where they were.
function pairTables(a, b) {
  var t = clone(b)
  var changed = false
  t.header = b.header.map(function(cell, c) {
    var m = Runs.markRuns(a.header[c] || [], cell)
    if (m.changed) changed = true
    return m.runs
  })
  var keyFn = function(row) { return norm(Inline.plain(row[0] || [])) }
  var rowText = function(row) { return row.map(Inline.plain).join(" ") }
  var bagA = lazyBags(a.rows, rowText), bagB = lazyBags(b.rows, rowText)
  var simOf = function(i, j) { return Words.dice(bagA(i), bagB(j)) }
  var p = Align.plan(a.rows, b.rows, keyFn, simOf, BLOCK_SIM)
  var byB = {}
  p.pairs.forEach(function(pr) { byB[pr[1]] = pr[0] })
  var where = slots(a.rows.length, b.rows.length, p.pairs)
  var rows = []
  function struck(row) { changed = true; return row.map(function(cell) { return Runs.markAll(cell, "del") }) }
  for (var j = 0; j < b.rows.length; j++) {
    (where.before[j] || []).forEach(function(i) { rows.push(struck(a.rows[i])) })
    var row = b.rows[j]
    if (byB[j] === undefined) { changed = true; rows.push(row.map(function(cell) { return Runs.markAll(cell, "ins") })); continue }
    var aRow = a.rows[byB[j]]
    rows.push(row.map(function(cell, c) {
      var m = Runs.markRuns(aRow[c] || [], cell)
      if (m.changed) changed = true
      return m.runs
    }))
  }
  where.trailing.forEach(function(i) { rows.push(struck(a.rows[i])) })
  t.rows = rows
  return finish(t, changed)
}

// ---- sequences of blocks (a section's body, a quote's children)

function mergeSequences(aBlocks, bBlocks) {
  var bagA = lazyBags(aBlocks, plainOf), bagB = lazyBags(bBlocks, plainOf)
  var simOf = function(i, j) {
    if (aBlocks[i].type !== bBlocks[j].type) return 0
    if (aBlocks[i].type === "image" || aBlocks[i].type === "hr") return 0
    return Words.dice(bagA(i), bagB(j))
  }
  var p = Align.plan(aBlocks, bBlocks, keyOf, simOf, BLOCK_SIM)
  var byB = {}
  p.pairs.forEach(function(pr) { byB[pr[1]] = pr })
  var where = slots(aBlocks.length, bBlocks.length, p.pairs)
  var out = [], total = 0
  function removed(b, anchorLine) { out.push(removedBlock(b, anchorLine)); total++ }
  for (var j = 0; j < bBlocks.length; j++) {
    (where.before[j] || []).forEach(function(i) { removed(aBlocks[i], bBlocks[j].srcStart) })
    var pr2 = byB[j]
    var blk
    if (!pr2) blk = mark(bBlocks[j], "added")
    else if (pr2[2]) blk = mark(bBlocks[j], "same")
    else {
      blk = pairBlocks(aBlocks[pr2[0]], bBlocks[j])
      // A type with no inner pairing (html, gallery) reads as removed then added.
      if (!blk) { removed(aBlocks[pr2[0]], bBlocks[j].srcStart); blk = mark(bBlocks[j], "added") }
    }
    total += blk.changes
    out.push(blk)
  }
  var last = bBlocks[bBlocks.length - 1]
  where.trailing.forEach(function(i) { removed(aBlocks[i], last ? last.srcEnd : undefined) })
  return { blocks: out, total: total }
}

// ---- sections

function sections(blocks) {
  var out = [{ heading: null, blocks: [] }]
  blocks.forEach(function(b) {
    if (b.type === "heading") out.push({ heading: b, blocks: [] })
    else out[out.length - 1].blocks.push(b)
  })
  return out
}

function sectionKey(s) { return s.heading ? s.heading.level + "\u0001" + norm(s.heading.text) : "\u0000" }

function bodyText(s) { return s.blocks.map(plainOf).join("\n") }

function compare(fromText, toText) {
  var a = Blocks.build(fromText || ""), b = Blocks.build(toText || "")
  var sa = sections(a.blocks), sb = sections(b.blocks)
  // Unmatched headings of one level pair when their words are alike, or
  // when their bodies are: a retitled section stays one section.
  var bodyBagA = lazyBags(sa, bodyText), bodyBagB = lazyBags(sb, bodyText)
  var simOf = function(i, j) {
    if (!sa[i].heading || !sb[j].heading || sa[i].heading.level !== sb[j].heading.level) return 0
    var byTitle = Words.similarity(sa[i].heading.text, sb[j].heading.text)
    if (byTitle >= SECTION_SIM) return byTitle
    var ba = bodyBagA(i), bb = bodyBagB(j)
    if (ba.n === 0 || bb.n === 0) return byTitle
    var byBody = Words.dice(ba, bb)
    return byBody >= SECTION_SIM ? Math.max(byTitle, byBody - 0.001) : byTitle
  }
  var p = Align.plan(sa, sb, sectionKey, simOf, SECTION_SIM)
  var byB = {}
  p.pairs.forEach(function(pr) { byB[pr[1]] = pr })
  var where = slots(sa.length, sb.length, p.pairs)
  var out = [], total = 0
  function emitRemovedSection(s, anchorLine) {
    var all = (s.heading ? [s.heading] : []).concat(s.blocks)
    all.forEach(function(blk) { out.push(removedBlock(blk, anchorLine)); total++ })
  }
  for (var j = 0; j < sb.length; j++) {
    var anchorLine = sb[j].heading ? sb[j].heading.srcStart : (sb[j].blocks[0] ? sb[j].blocks[0].srcStart : 0)
    ;(where.before[j] || []).forEach(function(i) { emitRemovedSection(sa[i], anchorLine) })
    var pr2 = byB[j]
    if (!pr2) {
      if (sb[j].heading) { out.push(mark(sb[j].heading, "added")); total++ }
      sb[j].blocks.forEach(function(blk) { out.push(mark(blk, "added")); total++ })
      continue
    }
    var from = sa[pr2[0]]
    if (sb[j].heading) {
      var h = pr2[2] ? mark(sb[j].heading, "same") : pairBlocks(from.heading, sb[j].heading)
      total += h.changes
      out.push(h)
    }
    var body = mergeSequences(from.blocks, sb[j].blocks)
    out = out.concat(body.blocks)
    total += body.total
  }
  where.trailing.forEach(function(i) { emitRemovedSection(sa[i], b.lineCount) })
  sectionCounts(out)
  return { blocks: out, total: total, lineCount: Math.max(1, b.lineCount), source: toText || "" }
}

// Words inserted and removed in a block: every run flagged ins or del, in
// the block's own runs, its list items, its quoted blocks and its table
// cells. A block added or removed whole counts all of its words.
function wordCounts(block) {
  var ins = 0, del = 0
  function words(t) { var m = String(t || "").match(/\S+/g); return m ? m.length : 0 }
  // `whole` is "added" or "removed" when the block, or an item or block
  // above it, changed as one: its runs carry no flags of their own.
  function runs(list, whole) {
    for (var i = 0; i < (list || []).length; i++) {
      var r = list[i]
      if (whole === "added" || r.ins) ins += words(r.t)
      if (whole === "removed" || r.del) del += words(r.t)
    }
  }
  function walk(b, whole) {
    if (!b) return
    if (b.change === "added" || b.change === "removed") whole = b.change
    if (b.runs) runs(b.runs, whole)
    if (b.header) runs(b.header.reduce(function(a, c) { return a.concat(c) }, []), whole)
    if (b.rows) b.rows.forEach(function(row) { row.forEach(function(cell) { runs(cell, whole) }) })
    if (b.blocks) b.blocks.forEach(function(c) { walk(c, whole) })
    if (b.items) b.items.forEach(function(it) { walk(it, whole) })
    if (b.type === "code" || b.type === "diff") {
      var n = words(b.text)
      if (whole === "added") ins += n
      if (whole === "removed") del += n
    }
  }
  walk(block, "")
  return { ins: ins, del: del }
}

// Each heading's count covers its body and every deeper heading until the
// next heading at its level or above, plus its own change. The words
// inserted and removed over the same span give the mix of the changes.
function sectionCounts(blocks) {
  var counts = blocks.map(wordCounts)
  for (var i = 0; i < blocks.length; i++) {
    blocks[i].insWords = counts[i].ins
    blocks[i].delWords = counts[i].del
  }
  for (var k = 0; k < blocks.length; k++) {
    if (blocks[k].type !== "heading") continue
    var n = blocks[k].changes || 0, ins = counts[k].ins, del = counts[k].del
    for (var j = k + 1; j < blocks.length; j++) {
      if (blocks[j].type === "heading" && blocks[j].level <= blocks[k].level) break
      n += blocks[j].changes || 0
      ins += counts[j].ins
      del += counts[j].del
    }
    blocks[k].sectionChanges = n
    blocks[k].sectionIns = ins
    blocks[k].sectionDel = del
  }
}

// The prepared document for MarkdownView.changes: the blocks with heading
// slugs stamped, plus headings, anchors and find pieces.
function document(result) {
  var ix = typeof Blocks.index === "function" ? Blocks.index(result.blocks) : indexBlocks(result.blocks)
  return { blocks: result.blocks, headings: ix.headings, anchors: ix.anchors, pieces: ix.pieces,
           lineCount: result.lineCount, source: result.source }
}

// Blocks.index as upstream OmaRead has it; kept until the vendored copy
// carries it, then this goes and document() calls Blocks.index alone.
function indexBlocks(blocks) {
  var seen = {}, headings = []
  for (var i = 0; i < blocks.length; i++) {
    var b = blocks[i]
    if (b.type !== "heading") continue
    var base = Blocks.slugify(b.text)
    var n = seen[base] || 0
    seen[base] = n + 1
    b.slug = n ? base + "-" + n : base
    headings.push({ level: b.level, text: b.text, slug: b.slug, index: i, srcStart: b.srcStart })
  }
  return { headings: headings, anchors: Blocks.anchors(blocks), pieces: Blocks.stampPieces(blocks) }
}

function changedIndices(blocks) {
  var out = []
  for (var i = 0; i < blocks.length; i++) if (blocks[i].change && blocks[i].change !== "same") out.push(i)
  return out
}
