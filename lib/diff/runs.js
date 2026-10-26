.pragma library
.import "words.js" as Words
.import "../inline.js" as Inline

// Word differences painted onto OmarkyReader runs.
//
// slice(runs, from, to)        -> runs for plain offsets [from, to)
// markRuns(fromRuns, toRuns)   -> { runs, changed }
// markAll(runs, kind)          -> runs flagged ins or del
//
// A run is OmarkyReader's { t, b, i, s, code, href, ... }; a marked run also
// carries `del: true` or `ins: true`. Plain offsets are positions in
// Inline.plain(runs), which is why slice can cut by character.

function copy(r) {
  var o = {}
  for (var k in r) o[k] = r[k]
  return o
}

// The runs covering plain-text offsets [from, to), split at the edges.
function slice(runs, from, to) {
  var out = [], at = 0
  for (var i = 0; i < (runs || []).length; i++) {
    var r = runs[i], len = r.t.length, end = at + len
    if (end > from && at < to) {
      var c = copy(r)
      c.t = r.t.slice(Math.max(0, from - at), Math.min(len, to - at))
      if (c.t.length) out.push(c)
    }
    at = end
    if (at >= to) break
  }
  return out
}

function markAll(runs, kind) {
  return (runs || []).map(function(r) { var c = copy(r); c[kind] = true; return c })
}

// The merged sequence: del runs sliced from fromRuns, eq and ins runs from
// toRuns, in diff order. Whitespace-only differences are not changes.
function markRuns(fromRuns, toRuns) {
  var a = Inline.plain(fromRuns), b = Inline.plain(toRuns)
  var segs = Words.spans(a, b)
  var out = [], changed = false
  for (var i = 0; i < segs.length; i++) {
    var s = segs[i]
    if (s.kind === "eq") out = out.concat(slice(toRuns, s.b0, s.b1))
    else if (s.kind === "del") { out = out.concat(markAll(slice(fromRuns, s.a0, s.a1), "del")); changed = true }
    else { out = out.concat(markAll(slice(toRuns, s.b0, s.b1), "ins")); changed = true }
  }
  return { runs: out, changed: changed }
}
