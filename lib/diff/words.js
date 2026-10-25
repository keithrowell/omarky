.pragma library

// Word-level differences between two texts.
//
// tokenize(text)            -> [{ t, key }]
// diff(a, b)                -> [{ kind, a0, a1, b0, b1 }]  (Myers, by key)
// segments(aText, bText)    -> [{ kind: eq|del|ins, text }]
// spans(aText, bText)       -> segments with a0, a1, b0, b1 character offsets
// similarity(aText, bText)  -> 0..1 (Dice over words)
// bag(text), dice(bagA, bagB) -> the same similarity with the bags reused
//
// A token is a word (letters, digits, underscore, apostrophes), a run of
// whitespace, or one punctuation mark. Whitespace tokens all share the key
// " ", so two texts that differ only in spacing or wrapping diff as equal.

// Punctuation: ASCII marks and symbols (apostrophe and underscore kept as
// word characters), Latin-1 symbols, general punctuation (the right single
// quote U+2019 kept, so "it’s" stays one word), arrows and symbol blocks,
// CJK punctuation. V4 has no \p{L}, so a word is the complement of
// whitespace and punctuation.
var PUNCT = "!-&(-\\/:-@\\[-\\^`{-~¡-¿×÷‐-‘‚-‧‰-⁞←-⯿　-〿"
var WORD = new RegExp("[^\\s" + PUNCT + "]+|\\s+|[" + PUNCT + "]", "g")
var WORDS_ONLY = new RegExp("[^\\s" + PUNCT + "]+", "g")
var SPACE = /^\s+$/
var NOT_APOSTROPHE = /[^'’]/

function tokenize(text) {
  var out = [], m
  var s = text === null || text === undefined ? "" : String(text)
  WORD.lastIndex = 0
  while ((m = WORD.exec(s)) !== null) {
    var t = m[0]
    out.push({ t: t, key: SPACE.test(t) ? " " : t })
  }
  return out
}

// Myers' O(ND) over keys; returns the edit script as eq/del/ins blocks
// with half-open ranges into a and b. Equal runs at the ends are trimmed
// first so the furthest-reaching search only covers the changed middle.
function diff(a, b) {
  var n = a.length, m = b.length
  var head = 0
  while (head < n && head < m && a[head].key === b[head].key) head++
  var tail = 0
  while (tail < n - head && tail < m - head && a[n - 1 - tail].key === b[m - 1 - tail].key) tail++
  var ops = []
  if (head) ops.push({ kind: "eq", a0: 0, a1: head, b0: 0, b1: head })
  var middle = myers(a, head, n - tail, b, head, m - tail)
  for (var i = 0; i < middle.length; i++) ops.push(middle[i])
  if (tail) ops.push({ kind: "eq", a0: n - tail, a1: n, b0: m - tail, b1: m })
  return merge(ops)
}

// The furthest-reaching search over a[aLo, aHi) and b[bLo, bHi).
function myers(a, aLo, aHi, b, bLo, bHi) {
  var n = aHi - aLo, m = bHi - bLo
  if (n === 0 && m === 0) return []
  if (n === 0) return [{ kind: "ins", a0: aLo, a1: aLo, b0: bLo, b1: bHi }]
  if (m === 0) return [{ kind: "del", a0: aLo, a1: aHi, b0: bLo, b1: bLo }]
  var max = n + m
  var v = {}, trace = []
  v[1] = 0
  var d, k, x, y, done = false
  for (d = 0; d <= max && !done; d++) {
    var snapshot = {}
    for (k = -d; k <= d; k += 2) {
      if (k === -d || (k !== d && v[k - 1] < v[k + 1])) x = v[k + 1]
      else x = v[k - 1] + 1
      y = x - k
      while (x < n && y < m && a[aLo + x].key === b[bLo + y].key) { x++; y++ }
      v[k] = x
      snapshot[k] = x
      if (x >= n && y >= m) { done = true; break }
    }
    trace.push(snapshot)
  }
  // Walk back from (n, m) through the snapshots.
  var ops = []
  x = n; y = m
  for (d = trace.length - 1; d > 0; d--) {
    var vv = trace[d - 1]
    k = x - y
    var prevK
    if (k === -d || (k !== d && vv[k - 1] < vv[k + 1])) prevK = k + 1
    else prevK = k - 1
    var prevX = vv[prevK], prevY = prevX - prevK
    while (x > prevX && y > prevY) { ops.push(op("eq", aLo + x - 1, aLo + x, bLo + y - 1, bLo + y)); x--; y-- }
    if (x === prevX) ops.push(op("ins", aLo + x, aLo + x, bLo + y - 1, bLo + y))
    else ops.push(op("del", aLo + x - 1, aLo + x, bLo + y, bLo + y))
    x = prevX; y = prevY
  }
  while (x > 0 && y > 0) { ops.push(op("eq", aLo + x - 1, aLo + x, bLo + y - 1, bLo + y)); x--; y-- }
  ops.reverse()
  return ops
}

function op(kind, a0, a1, b0, b1) { return { kind: kind, a0: a0, a1: a1, b0: b0, b1: b1 } }

function merge(ops) {
  var out = []
  for (var i = 0; i < ops.length; i++) {
    var o = ops[i]
    if (o.a0 === o.a1 && o.b0 === o.b1) continue
    var last = out[out.length - 1]
    if (last && last.kind === o.kind && last.a1 === o.a0 && last.b1 === o.b0) { last.a1 = o.a1; last.b1 = o.b1 }
    else out.push(op(o.kind, o.a0, o.a1, o.b0, o.b1))
  }
  return out
}

function join(tokens, from, to) {
  var s = ""
  for (var i = from; i < to; i++) s += tokens[i].t
  return s
}

function onlySpace(tokens, from, to) {
  for (var i = from; i < to; i++) if (tokens[i].key !== " ") return false
  return true
}

// eq and ins text comes from b, del text from a. Whitespace that only
// moved is not a change: a deleted space is dropped, an inserted space
// reads as equal, so the result spells the new side's spacing.
//
// Whitespace matched between two changes does not split them: "alpha beta"
// against "gamma delta" is one del and one ins, not two of each with a
// shared space between. The del keeps the old side's spacing and the ins
// the new side's, so each is a contiguous slice of its own text.
function segments(aText, bText) {
  return spans(aText, bText).map(function(s) { return { kind: s.kind, text: s.text } })
}

// segments() with character offsets: [a0, a1) into aText and [b0, b1) into
// bText. An eq span covers both sides (its text is b's), a del covers a
// only (b0 === b1), an ins covers b only (a0 === a1).
function spans(aText, bText) {
  var a = tokenize(aText), b = tokenize(bText)
  var ops = diff(a, b), raw = []
  var posA = 0, posB = 0
  for (var i = 0; i < ops.length; i++) {
    var o = ops[i]
    var ta = join(a, o.a0, o.a1), tb = join(b, o.b0, o.b1)
    var s = { kind: o.kind, text: tb, a: ta, ws: false, a0: posA, a1: posA + ta.length, b0: posB, b1: posB + tb.length }
    posA = s.a1; posB = s.b1
    if (o.kind === "eq") s.ws = onlySpace(b, o.b0, o.b1)
    else if (o.kind === "del") { s.text = ta; if (onlySpace(a, o.a0, o.a1)) { s.kind = "eq"; s.text = ""; s.ws = true } }
    else if (onlySpace(b, o.b0, o.b1)) { s.kind = "eq"; s.ws = true }
    raw.push(s)
  }
  var out = []
  function push(kind, text, a0, a1, b0, b1) {
    if (!text) return
    var last = out[out.length - 1]
    if (last && last.kind === kind) { last.text += text; last.a1 = a1; last.b1 = b1 }
    else out.push({ kind: kind, text: text, a0: a0, a1: a1, b0: b0, b1: b1 })
  }
  var j = 0
  while (j < raw.length) {
    var r = raw[j]
    if (r.kind === "eq") { push("eq", r.text, r.a0, r.a1, r.b0, r.b1); j++; continue }
    var del = "", ins = "", a0 = r.a0, b0 = r.b0, a1 = a0, b1 = b0
    while (j < raw.length) {
      var s2 = raw[j]
      if (s2.kind === "del") del += s2.text
      else if (s2.kind === "ins") ins += s2.text
      else if (s2.ws && j + 1 < raw.length && raw[j + 1].kind !== "eq") { del += s2.a; ins += s2.text }
      else break
      a1 = s2.a1; b1 = s2.b1
      j++
    }
    push("del", del, a0, a1, b0, b0)
    push("ins", ins, a1, a1, b0, b1)
  }
  return out
}

// The lower-cased words of a text with their counts: { bag, n }. Callers
// comparing many texts compute each bag once and pass them to dice().
function bag(text) {
  var counts = {}, n = 0, m
  var s = text === null || text === undefined ? "" : String(text)
  WORDS_ONLY.lastIndex = 0
  while ((m = WORDS_ONLY.exec(s)) !== null) {
    if (!NOT_APOSTROPHE.test(m[0])) continue
    var w = m[0].toLowerCase()
    counts[w] = (counts[w] || 0) + 1
    n++
  }
  return { bag: counts, n: n }
}

// Dice coefficient of two bags: 2 * shared / (n + m). Two empty texts are
// alike (1); an empty text against words is not (0).
function dice(a, b) {
  if (a.n === 0 && b.n === 0) return 1
  if (a.n === 0 || b.n === 0) return 0
  var small = a.n <= b.n ? a : b, large = small === a ? b : a
  var shared = 0
  for (var w in small.bag) if (large.bag[w]) shared += Math.min(small.bag[w], large.bag[w])
  return 2 * shared / (a.n + b.n)
}

// Dice coefficient over lower-cased word tokens (punctuation ignored).
function similarity(aText, bText) {
  return dice(bag(aText), bag(bText))
}
