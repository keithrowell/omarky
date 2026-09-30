import QtQuick
import qs.Commons
import qs.services
import qs.components

// h1–h6 on a 1.25 modular scale. h1/h2 carry a faint hairline; on hover a
// `#` appears in the left margin and copies file.md#slug.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})
  readonly property int level: block.level
  readonly property real step: [0, 3, 2, 1, 0.5, 0, 0][level]

  implicitHeight: text.implicitHeight + (rule.visible ? rule.gap + 1 : 0)

  RichText {
    id: text
    width: parent.width
    runs: root.block.runs
    size: Reading.size(root.step)
    leading: root.level <= 2 ? 1.25 : 1.35
    family: Reading.heading
    styleName: root.level >= 5 ? "Regular" : Reading.headingStyle
    baseColor: root.level >= 5 ? Theme.dim : Theme.strong
    tracking: root.level === 6 ? 0.6 : 0
    capitals: root.level === 6
  }

  Rectangle {
    id: rule
    readonly property real gap: Math.round(Reading.body * 0.45)
    visible: root.level <= 2
    y: text.implicitHeight + gap
    width: parent.width
    height: 1
    color: root.level === 1 ? Theme.hairline : Theme.hairlineSoft
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
