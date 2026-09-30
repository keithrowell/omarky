import QtQuick
import qs.services

// A column of child blocks (inside a list item, quote, alert or footnote),
// spaced with the same rhythm as the page. `look` passes text size and
// tier down to nested text (quotes read one step smaller and dimmer).
Column {
  id: root
  property var blocks: []
  property var ctx: null
  property var look: ({})
  // Tight lists pull a nested list or second paragraph close.
  property bool tight: false

  Repeater {
    model: root.blocks
    Item {
      id: slot
      required property var modelData
      required property int index
      width: root.width
      height: child.height + gap
      readonly property real gap: {
        if (index === 0) return 0
        var prev = root.blocks[index - 1]
        if (root.tight && (modelData.type === "list" || prev.type === "list")) return Math.round(Reading.body * 0.3)
        return Math.min(Reading.gapBefore(prev, modelData), Math.round(Reading.body * 0.9))
      }
      Block {
        id: child
        y: slot.gap
        width: slot.width
        block: slot.modelData
        ctx: root.ctx
        look: root.look
      }
    }
  }
}
