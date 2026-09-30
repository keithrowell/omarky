import QtQuick
import qs.services
import qs.components

// Notes gathered at the end under a hairline. Each note leads with its
// number in the accent colour and ends with links back to where it was
// cited.
Column {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property real textSize: Math.round(Reading.body * 0.88)
  readonly property real numW: Math.round(Reading.body * 1.9)
  spacing: Math.round(Reading.body * 0.55)

  // The note's blocks with back-links appended to its last paragraph.
  function withBacklinks(item) {
    var blocks = item.blocks.slice()
    var back = []
    for (var i = 1; i <= Math.max(1, item.refs); i++) {
      if (item.refs === 0) break
      back.push({ t: " ↩" + (item.refs > 1 ? String(i) : ""), href: "#fnref-" + item.number + "-" + i })
    }
    var last = blocks.length ? blocks[blocks.length - 1] : null
    if (last && last.type === "paragraph") {
      blocks[blocks.length - 1] = Object.assign({}, last, { runs: last.runs.concat(back) })
    } else if (back.length) {
      blocks.push({ type: "paragraph", runs: back, srcStart: -1, srcEnd: -1 })
    }
    return blocks
  }

  Item {
    width: parent.width
    height: Math.round(Reading.body * 0.6)
    Rectangle { width: Math.round(parent.width * 0.3); height: 1; color: Theme.hairline }
  }

  Repeater {
    model: root.block.items

    Item {
      id: note
      required property var modelData
      width: root.width
      height: body.height

      Text {
        width: root.numW
        height: Math.round(root.textSize * Reading.lineHeight)
        verticalAlignment: Text.AlignVCenter
        text: note.modelData.number + "."
        textFormat: Text.PlainText
        color: Theme.accent
        font.family: Reading.mono
        font.pixelSize: Math.round(root.textSize * 0.9)
        font.features: { "tnum": 1 }
        HoverHandler { cursorShape: note.modelData.refs > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: if (root.ctx && note.modelData.refs > 0) root.ctx.openLink("#fnref-" + note.modelData.number + "-1") }
      }

      BlockStack {
        id: body
        x: root.numW
        width: parent.width - root.numW
        blocks: root.withBacklinks(note.modelData)
        ctx: root.ctx
        look: ({ size: root.textSize, tier: "dim", contained: true })
      }
    }
  }
}
