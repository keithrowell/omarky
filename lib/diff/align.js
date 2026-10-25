.pragma library

// Aligning two block sequences.
//
// lcs(a, b, keyOf)                                -> [[i, j]] exact matches in order
// pairBySimilarity(aIdx, bIdx, simOf, threshold)  -> [[i, j]] non-crossing pairs
// plan(a, b, keyOf, simOf, threshold)             -> { pairs: [[i, j, exact]], removed, added }
//
// plan() takes the exact matches first, then pairs what is left by
// similarity inside each gap between exact matches, so no pair crosses
// another. Sequences are blocks or sections (hundreds at most), so the
// quadratic table is cheap.

function lcs(a, b, keyOf) {
  var n = a.length, m = b.length
  if (!n || !m) return []
  var ka = a.map(keyOf), kb = b.map(keyOf)
  var L = []
  for (var i = 0; i <= n; i++) { L.push(new Array(m + 1)); for (var j = 0; j <= m; j++) L[i][j] = 0 }
  for (i = n - 1; i >= 0; i--) for (j = m - 1; j >= 0; j--)
    L[i][j] = ka[i] === kb[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1])
  var out = []
  i = 0; j = 0
  while (i < n && j < m) {
    if (ka[i] === kb[j]) { out.push([i, j]); i++; j++ }
    else if (L[i + 1][j] >= L[i][j + 1]) i++
    else j++
  }
  return out
}

// Greedy by similarity: the best pair first, then any pair that shares no
// member with a chosen pair and does not cross one. Ties go to the pair
// whose members sit at the same position in their lists.
function pairBySimilarity(aIdx, bIdx, simOf, threshold) {
  var cands = []
  for (var x = 0; x < aIdx.length; x++) for (var y = 0; y < bIdx.length; y++) {
    var s = simOf(aIdx[x], bIdx[y])
    if (s >= threshold) cands.push({ i: aIdx[x], j: bIdx[y], s: s, off: Math.abs(x - y) })
  }
  cands.sort(function(p, q) { return q.s - p.s || p.off - q.off || p.i - q.i || p.j - q.j })
  var chosen = []
  for (var c = 0; c < cands.length; c++) {
    var k = cands[c], ok = true
    for (var d = 0; d < chosen.length; d++) {
      var e = chosen[d]
      if (e.i === k.i || e.j === k.j || (e.i < k.i) !== (e.j < k.j)) { ok = false; break }
    }
    if (ok) chosen.push(k)
  }
  chosen.sort(function(p, q) { return p.i - q.i })
  return chosen.map(function(k) { return [k.i, k.j] })
}

function plan(a, b, keyOf, simOf, threshold) {
  var exact = lcs(a, b, keyOf)
  var usedA = {}, usedB = {}
  exact.forEach(function(p) { usedA[p[0]] = true; usedB[p[1]] = true })
  var pairs = exact.map(function(p) { return [p[0], p[1], true] })
  // Similarity pairs may not cross exact ones: pair within each gap.
  var bounds = [[-1, -1]].concat(exact).concat([[a.length, b.length]])
  for (var g = 0; g + 1 < bounds.length; g++) {
    var ga = [], gb = []
    for (var x = bounds[g][0] + 1; x < bounds[g + 1][0]; x++) if (!usedA[x]) ga.push(x)
    for (var y = bounds[g][1] + 1; y < bounds[g + 1][1]; y++) if (!usedB[y]) gb.push(y)
    if (!ga.length || !gb.length) continue
    pairBySimilarity(ga, gb, simOf, threshold).forEach(function(p) {
      pairs.push([p[0], p[1], false])
      usedA[p[0]] = true; usedB[p[1]] = true
    })
  }
  pairs.sort(function(p, q) { return p[0] - q[0] })
  var removed = [], added = []
  for (var i = 0; i < a.length; i++) if (!usedA[i]) removed.push(i)
  for (var j = 0; j < b.length; j++) if (!usedB[j]) added.push(j)
  return { pairs: pairs, removed: removed, added: added }
}
