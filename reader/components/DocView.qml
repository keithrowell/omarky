import QtQuick
import qs.Commons
import qs.services

// The reading column: a ListView over the flat block list, one delegate per
// block, centred at a measure computed from the body font's metrics.
ListView {
  id: root
  property var blocks: []
  property bool wide: false
  property var ctx: null

  readonly property real measure: Math.round(bodyMetrics.averageCharacterWidth * (wide ? 100 : 68))
  readonly property real column: Math.min(measure, width - Style.space(48) * 2)
  readonly property real gutter: Math.round((width - column) / 2)

  function pageDown() {
    if (atYEnd) return false
    var step = height - Style.space(80)
    contentY = Math.min(contentY + step, Math.max(originY, originY + contentHeight - height))
    return true
  }

  FontMetrics { id: bodyMetrics; font.family: Reading.prose; font.styleName: "Regular"; font.pixelSize: Reading.body }

  model: blocks
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  cacheBuffer: 2000
  header: Item { height: Style.space(56) }
  footer: Item { height: Style.space(120) }

  delegate: Item {
    id: row
    required property var modelData
    required property int index
    width: root.width
    height: block.height + gap
    readonly property real gap: Reading.gapBefore(index > 0 ? root.blocks[index - 1] : null, modelData)

    Block {
      id: block
      x: root.gutter
      y: row.gap
      width: root.column
      block: row.modelData
      ctx: root.ctx
    }
  }
}
