import QtQuick
import qs.Commons
import qs.services
import qs.components

// h1–h6 on a 1.25 modular scale. On hover a `#` appears in the left margin
// and copies file.md#slug.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})
  readonly property int level: block.level
  readonly property real step: [0, 3, 2, 1, 0.5, 0, 0][level]

  implicitHeight: text.implicitHeight

  RichText {
    id: text
    width: parent.width
    runs: root.block.runs
    ctx: root.ctx
    pid: root.block.pid !== undefined ? root.block.pid : -1
    size: Reading.size(root.step)
    leading: root.level <= 2 ? 1.25 : 1.35
    family: Reading.heading
    styleName: root.level >= 5 ? "Regular" : Reading.headingStyle
    baseColor: root.level >= 5 ? Theme.dim : Theme.strong
    tracking: root.level === 6 ? 0.6 : 0
    capitals: root.level === 6
  }

  HoverHandler { id: hover }

  Text {
    id: anchor
    x: -width - Math.round(Reading.body * 0.6)
    y: text.firstLineY
    height: text.lineHeightPx
    verticalAlignment: Text.AlignVCenter
    text: "#"
    font.family: Reading.mono
    font.pixelSize: Math.round(Reading.body * 0.95)
    color: anchorHover.hovered ? Theme.accent : Theme.faint
    opacity: hover.hovered ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on color { ColorAnimation { duration: 120 } }
    HoverHandler { id: anchorHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (root.ctx) root.ctx.copyAnchor(root.block.slug) }
  }
}
