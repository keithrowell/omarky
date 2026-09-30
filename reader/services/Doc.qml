import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/blocks.js" as Blocks

// One open Markdown file: loads it, watches it, parses it and exposes the
// block model. Changes on disk are debounced (editors write in bursts) and
// re-parsed; views get aboutToReload/reloaded around the swap so they can
// keep the reader's place. A deleted file keeps its last content and is
// polled until it comes back.
Item {
  id: root

  property string path: ""
  property string source: ""
  property var blocks: []
  property var headings: []
  property var anchorMap: ({})
  property var pieces: []
  property int lineCount: 0
  property bool loaded: false
  property bool missing: false
  property bool failed: false
  property int parseMs: 0
  property int reloads: 0

  signal aboutToReload()
  signal reloaded()

  function parse(text) {
    var t0 = Date.now()
    var doc = Blocks.build(text)
    parseMs = Date.now() - t0
    var first = !loaded
    if (!first) aboutToReload()
    source = text
    headings = doc.headings
    anchorMap = doc.anchors
    pieces = doc.pieces
    lineCount = doc.lineCount
    blocks = doc.blocks
    loaded = true
    missing = false
    failed = false
    if (!first) { reloads++; reloaded() }
  }

  function reload() {
    if (path) file.reload()
  }

  // The Markdown source of lines [start, end).
  function sourceLines(start, end) {
    return source.split("\n").slice(Math.max(0, start), Math.max(start, end)).join("\n")
  }

  FileView {
    id: file
    path: root.path
    watchChanges: true
    printErrors: false
    onLoaded: root.parse(text())
    onLoadFailed: {
      if (root.loaded) root.missing = true
      else root.failed = true
    }
    onFileChanged: debounce.restart()
  }

  Timer {
    id: debounce
    interval: 150
    onTriggered: file.reload()
  }

  // While the file is gone, look for it again every second.
  Timer {
    interval: 1000
    repeat: true
    running: root.missing || root.failed
    onTriggered: file.reload()
  }
}
