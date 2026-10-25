.pragma library

// Collapse the unchanged.
//
// fold(blocks, open)          -> blocks with fold rows
// unfoldedIndex(folded, i)    -> the unfolded index of folded row i
// openRange(folded, i)        -> [first, last] unfolded indices a click on row i opens
//
// `blocks` is Changes.compare(...).blocks; `open` is an object whose keys
// are unfolded top-level indices the user has opened: a run stays open
// when any of its indices is open, a section when its heading's index is.
// Recording a fold row's `index` is enough. A run of consecutive `same`
// non-heading blocks becomes
//   { type: "fold", count, kinds, index, srcStart, srcEnd, change: "same", changes: 0 }
// where `index` is the unfolded index of the first folded block and
// `kinds` is the shared block type, or "block" when they differ. A heading
// whose section has no changes becomes
//   { type: "fold", heading, count, index, srcStart, srcEnd, change: "same", changes: 0 }
// and its whole section, to the next heading at its level or above, is
// dropped. Every other block is copied through with `index` set.

function fold(blocks, open) {
  open = open || {}
  var out = [], i = 0
  while (i < blocks.length) {
    var b = blocks[i]
    if (b.type === "heading" && (b.sectionChanges || 0) === 0 && !open[i]) {
      var j = sectionEnd(blocks, i)
      out.push({ type: "fold", heading: b, count: j - i - 1, index: i, srcStart: b.srcStart, srcEnd: blocks[j - 1].srcEnd, change: "same", changes: 0 })
      i = j
      continue
    }
    if (b.type !== "heading" && b.change === "same") {
      // The run is defined by its content; one open index opens all of it.
      var k = i, kinds = b.type, isOpen = false
      while (k < blocks.length && blocks[k].type !== "heading" && blocks[k].change === "same") {
        if (blocks[k].type !== kinds) kinds = "block"
        if (open[k]) isOpen = true
        k++
      }
      if (isOpen) { for (var r = i; r < k; r++) out.push(through(blocks[r], r)) }
      else out.push({ type: "fold", count: k - i, kinds: kinds, index: i, srcStart: b.srcStart, srcEnd: blocks[k - 1].srcEnd, change: "same", changes: 0 })
      i = k
      continue
    }
    out.push(through(b, i))
    i++
  }
  return out
}

function through(b, i) {
  var c = {}
  for (var key in b) c[key] = b[key]
  c.index = i
  return c
}

// The index just past heading i's section: the next heading at its level
// or above, or the end.
function sectionEnd(blocks, i) {
  var j = i + 1
  while (j < blocks.length && !(blocks[j].type === "heading" && blocks[j].level <= blocks[i].level)) j++
  return j
}

// The unfolded index of folded row `i`.
function unfoldedIndex(folded, i) { return folded[i] ? folded[i].index : -1 }

// The unfolded indices a click on folded row `i` opens, as [first, last]
// inclusive: the run for a run fold, the heading and its whole section
// for a section fold, the row itself for anything else.
function openRange(folded, i) {
  var row = folded[i]
  if (!row) return [-1, -1]
  if (row.type !== "fold") return [row.index, row.index]
  return [row.index, row.index + row.count - (row.heading ? 0 : 1)]
}
