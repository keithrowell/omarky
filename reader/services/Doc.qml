import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/blocks.js" as Blocks

// One open Markdown file: loads it, watches it and exposes the block model.
Item {
  id: root

  property string path: ""
  property string source: ""
  property var blocks: []
  property var headings: []
  property var anchorMap: ({})
  property int lineCount: 0
  property bool loaded: false

  function parse(text) {
    root.source = text
    var doc = Blocks.build(text)
    root.headings = doc.headings
    root.anchorMap = doc.anchors
    root.lineCount = doc.lineCount
    root.blocks = doc.blocks
    root.loaded = true
  }

  FileView {
    id: file
    path: root.path
    printErrors: false
    onLoaded: root.parse(text())
  }
}
