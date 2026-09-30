import QtQuick
import qs.Commons
import qs.services
import qs.components

// GFM alert: a tinted card in the kind's theme colour, an icon and a small
// mono title, then the body.
Rectangle {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property color tint: ({ note: Theme.blue, tip: Theme.green, important: Theme.magenta,
                                   warning: Theme.yellow, caution: Theme.red })[block.kind] || Theme.accent
  // Nerd Font octicons, as on GitHub.
  readonly property string icon: ({ note: "\uf449", tip: "\uf400", important: "\uf50a",
                                    warning: "\uf421", caution: "\uf52f" })[block.kind] || "\uf449"
  readonly property real pad: Math.round(Reading.body * 1.05)

  implicitHeight: content.implicitHeight + pad * 2
  radius: Math.max(4, Style.cornerRadius)
  color: Util.alpha(tint, Theme.light ? 0.075 : 0.09)
  border.width: 1
  border.color: Util.alpha(tint, Theme.light ? 0.3 : 0.24)

  Column {
    id: content
    x: root.pad
    y: root.pad
    width: parent.width - root.pad * 2
    spacing: Math.round(Reading.body * 0.5)

    Row {
      spacing: Math.round(Reading.body * 0.5)
      Text {
        text: root.icon
        color: root.tint
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(Reading.body * 0.95)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: root.block.title
        color: root.tint
        font.family: Reading.mono
        font.styleName: "Bold"
        font.pixelSize: Math.round(Reading.body * 0.76)
        font.letterSpacing: Math.round(Reading.body * 0.08)
        font.capitalization: Font.AllUppercase
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    BlockStack {
      width: parent.width
      blocks: root.block.blocks
      ctx: root.ctx
      look: Object.assign({}, root.look, { contained: true })
    }
  }
}
