.pragma library

// Footnotes for markdown-it: `[^label]: text` definitions (with indented
// continuation lines) and `[^label]` references. Modelled on
// markdown-it-footnote (MIT) but reduced to what OmaRead draws: it emits
//   footnote_reference_open/close  around a definition's block tokens
//   footnote_ref                   inline, meta { id, subId, label }
// and records env.footnotes = { refs: {":label": id}, list: [{label, count}] }.
// lib/blocks.js gathers the definitions into one block at the end.

function isSpace(code) { return code === 0x09 || code === 0x20 }

function footnoteDef(state, startLine, endLine, silent) {
  var start = state.bMarks[startLine] + state.tShift[startLine]
  var max = state.eMarks[startLine]
  if (start + 4 > max) return false
  if (state.src.charCodeAt(start) !== 0x5B /* [ */) return false
  if (state.src.charCodeAt(start + 1) !== 0x5E /* ^ */) return false

  var pos
  for (pos = start + 2; pos < max; pos++) {
    if (state.src.charCodeAt(pos) === 0x20) return false
    if (state.src.charCodeAt(pos) === 0x5D /* ] */) break
  }
  if (pos === start + 2) return false
  if (pos + 1 >= max || state.src.charCodeAt(++pos) !== 0x3A /* : */) return false
  if (silent) return true
  pos++

  if (!state.env.footnotes) state.env.footnotes = {}
  if (!state.env.footnotes.refs) state.env.footnotes.refs = {}
  var label = state.src.slice(start + 2, pos - 2)
  if (!(":" + label in state.env.footnotes.refs)) state.env.footnotes.refs[":" + label] = -1

  var open = new state.Token("footnote_reference_open", "", 1)
  open.meta = { label: label }
  open.level = state.level++
  open.map = [startLine, startLine + 1]
  state.tokens.push(open)

  var oldBMark = state.bMarks[startLine]
  var oldTShift = state.tShift[startLine]
  var oldSCount = state.sCount[startLine]
  var oldParentType = state.parentType
  var posAfterColon = pos
  var initial = state.sCount[startLine] + pos - (state.bMarks[startLine] + state.tShift[startLine])
  var offset = initial

  while (pos < max) {
    var ch = state.src.charCodeAt(pos)
    if (!isSpace(ch)) break
    offset += ch === 0x09 ? 4 - offset % 4 : 1
    pos++
  }

  state.tShift[startLine] = pos - posAfterColon
  state.sCount[startLine] = offset - initial
  state.bMarks[startLine] = posAfterColon
  state.blkIndent += 4
  state.parentType = "footnote"
  if (state.sCount[startLine] < state.blkIndent) state.sCount[startLine] += state.blkIndent

  state.md.block.tokenize(state, startLine, endLine, true)

  state.parentType = oldParentType
  state.blkIndent -= 4
  state.tShift[startLine] = oldTShift
  state.sCount[startLine] = oldSCount
  state.bMarks[startLine] = oldBMark
  open.map[1] = state.line

  var close = new state.Token("footnote_reference_close", "", -1)
  close.level = --state.level
  state.tokens.push(close)
  return true
}

function footnoteRef(state, silent) {
  var max = state.posMax
  var start = state.pos
  if (start + 3 > max) return false
  if (!state.env.footnotes || !state.env.footnotes.refs) return false
  if (state.src.charCodeAt(start) !== 0x5B) return false
  if (state.src.charCodeAt(start + 1) !== 0x5E) return false

  var pos
  for (pos = start + 2; pos < max; pos++) {
    var c = state.src.charCodeAt(pos)
    if (c === 0x20 || c === 0x0A) return false
    if (c === 0x5D) break
  }
  if (pos === start + 2 || pos >= max) return false
  pos++

  var label = state.src.slice(start + 2, pos - 1)
  var refs = state.env.footnotes.refs
  if (!(":" + label in refs)) return false

  if (!silent) {
    if (!state.env.footnotes.list) state.env.footnotes.list = []
    var id = refs[":" + label]
    if (id < 0) {
      id = state.env.footnotes.list.length
      state.env.footnotes.list[id] = { label: label, count: 0 }
      refs[":" + label] = id
    }
    var subId = state.env.footnotes.list[id].count++
    var token = state.push("footnote_ref", "", 0)
    token.meta = { id: id, subId: subId, label: label }
  }
  state.pos = pos
  state.posMax = max
  return true
}

function plugin(md) {
  md.block.ruler.before("reference", "footnote_def", footnoteDef, { alt: ["paragraph", "reference"] })
  md.inline.ruler.after("image", "footnote_ref", footnoteRef)
}
