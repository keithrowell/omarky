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
  property bool loaded: false

  function parse(text) {
    root.source = text
    root.blocks = Blocks.build(text).blocks
    root.loaded = true
  }

  FileView {
    id: file
    path: root.path
    printErrors: false
    onLoaded: root.parse(text())
  }
}
