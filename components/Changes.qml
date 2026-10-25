import QtQuick
import Quickshell.Io
import "../lib/blocks.js" as Blocks
import "../lib/diff/changes.js" as Engine
import "../lib/diff/fold.js" as Fold

// Changes mode for one window: the two sides being compared, the engine's
// result as a prepared document for MarkdownView, and the fold. A side is
// what `omaread FILE --resolve SPEC` prints: { label, who, name, when, long,
// sha, subject, body, text }, or { label: "Now", who: "Now" } for the file
// on disk, whose text this item reads and watches itself.
Item {
  id: root
  property string path: ""
  property var from: null
  property var to: null
  readonly property bool active: !!from && !!to
  property string nowText: ""
  readonly property bool usesNow: active && (from.label === "Now" || to.label === "Now")
  readonly property string fromText: !from ? "" : from.label === "Now" ? nowText : (from.text || "")
  readonly property string toText: !to ? "" : to.label === "Now" ? nowText : (to.text || "")
  property var result: null
  property var document: null
  readonly property int total: result ? result.total : 0
  property int compareMs: 0
  property string banner: ""
  // The file on disk changed while it was a side of the comparison.
  signal diskChanged()

  // The fold: runs of unchanged blocks and untouched sections collapse to
  // one row each; `open` holds the block indices the reader has opened.
  property bool foldOn: false
  property var open: ({})
  onFoldOnChanged: open = ({})
  readonly property var fullBlocks: result ? result.blocks : []
  readonly property var shown: {
    if (!document) return null
    if (!foldOn) return document
    var folded = Fold.fold(fullBlocks, open)
    var ix = Blocks.index(folded)
    // Folded sections keep their place in the outline.
    var headings = ix.headings.slice()
    for (var i = 0; i < folded.length; i++) {
      var b = folded[i]
      if (b.type === "fold" && b.heading) headings.push({ level: b.heading.level, text: b.heading.text, slug: b.heading.slug || "", index: i, srcStart: b.srcStart })
    }
    headings.sort(function(a, b) { return a.index - b.index })
    return { blocks: folded, headings: headings, anchors: ix.anchors, pieces: ix.pieces, lineCount: document.lineCount, source: document.source }
  }

  function run() {
    if (!active) { result = null; document = null; banner = ""; return }
    var t0 = Date.now()
    result = Engine.compare(fromText, toText)
    compareMs = Date.now() - t0
    document = Engine.document(result)
    banner = fromText === toText ? "No changes since " + from.who + ", " + from.when + "." : ""
  }
  onFromTextChanged: run()
  onToTextChanged: run()
  onActiveChanged: run()

  function clear() {
    from = null
    to = null
    foldOn = false
    open = ({})
  }

  // Opens the fold row at block index `i` of `blocks` (the shown document).
  function unfold(blocks, i) {
    var row = blocks[i]
    if (!row || row.type !== "fold") return
    var range = Fold.openRange(blocks, i)
    var o = Object.assign({}, open)
    for (var k = range[0]; k <= range[1]; k++) o[k] = true
    open = o
  }

  function changedIndices(blocks) { return Engine.changedIndices(blocks) }

  // The file on disk is a side: a change re-runs the comparison in place.
  FileView {
    id: disk
    path: root.usesNow ? root.path : ""
    watchChanges: true
    printErrors: false
    property bool first: true
    onPathChanged: first = true
    onFileChanged: debounce.restart()
    onLoaded: {
      root.nowText = text()
      if (first) first = false
      else root.diskChanged()
    }
  }
  Timer { id: debounce; interval: 150; onTriggered: disk.reload() }
}
