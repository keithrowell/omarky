import QtQuick
import qs.services
import qs.components

// Someone else's voice: an accent bar, text one step smaller and dimmer,
// nested quotes stepped in.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property real barWidth: Math.max(2, Math.round(Reading.body / 6))
  readonly property int depth: (look.quoteDepth || 0) + 1
  // Deeply nested quotes stop stepping in (malformed input).
  readonly property real inset: depth <= 8 ? Math.round(Reading.body * 1.2) : Math.round(Reading.body * 0.5)
  implicitHeight: stack.height

  Rectangle {
    width: root.barWidth
    height: parent.height
    radius: width / 2
    color: Theme.mix(Theme.accent, Theme.bg, 0.35)
  }

  BlockStack {
    id: stack
    x: root.inset
    width: parent.width - root.inset
    blocks: root.block.blocks
    ctx: root.ctx
    look: ({ size: Math.round(Reading.body * 0.94), tier: "dim", contained: true, quoteDepth: root.depth })
  }
}
