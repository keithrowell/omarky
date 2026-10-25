import QtQuick
import qs.Commons
import qs.services
import qs.components

// A run of unchanged blocks folded to one hairline row ("3 paragraphs
// unchanged"), or an unchanged section folded to its dimmed heading
// (MarkdownView.changes). Clicking asks the view to unfold it.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})
  readonly property bool section: !!block.heading
  readonly property int level: section ? block.heading.level : 0
  readonly property real headingSize: section ? Reading.size([0, 3, 2, 1, 0.5, 0, 0][level]) : Reading.body

  implicitHeight: section ? headingText.implicitHeight : Math.round(Reading.body * 1.6)

  function label() {
    var n = block.count || 0
    var noun = block.kinds === "paragraph" ? (n === 1 ? "paragraph" : "paragraphs") : (n === 1 ? "block" : "blocks")
    return n + " " + noun + " unchanged"
  }

  // Hover shading on the same edges as a change wash (DocView), so the
  // boxes down the page line up.
  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -Reading.washPad
    anchors.rightMargin: -Reading.washPad
    anchors.topMargin: -Style.space(6)
    anchors.bottomMargin: -Style.space(6)
    z: -1
    radius: Math.max(4, Style.cornerRadius - 2)
    color: hover.hovered ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Reading.motion(120) } }
  }

  // A whole section: its heading, dimmed, tagged "unchanged" in the margin
  // like any other block.
  Text {
    id: headingText
    visible: root.section
    width: parent.width
    wrapMode: Text.Wrap
    lineHeight: root.level <= 2 ? 1.25 : 1.35
    text: root.section ? root.block.heading.text : ""
    textFormat: Text.PlainText
    font.family: Reading.heading
    font.styleName: root.level >= 5 ? "Regular" : Reading.headingStyle
    font.pixelSize: root.headingSize
    color: Theme.dim
  }
  ChangeTag {
    visible: root.section
    change: "unchanged"
    x: -width - Math.round(Reading.body * 1.9)
    // Centred on the first line, as the tags on other blocks are.
    y: Math.round(headingText.contentHeight / Math.max(1, headingText.lineCount) / 2 - height / 2)
  }

  // A run of blocks: a hairline each side of the count.
  Item {
    visible: !root.section
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: countLabel.implicitHeight
    readonly property real side: Math.max(0, (width - countLabel.implicitWidth) / 2 - Math.round(Reading.body * 0.8))
    Rectangle { x: 0; width: parent.side; height: 1; color: Theme.hairlineSoft; anchors.verticalCenter: parent.verticalCenter }
    Text {
      id: countLabel
      anchors.centerIn: parent
      text: root.label()
      textFormat: Text.PlainText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Theme.faint
    }
    Rectangle { x: parent.width - parent.side; width: parent.side; height: 1; color: Theme.hairlineSoft; anchors.verticalCenter: parent.verticalCenter }
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: if (root.ctx && root.ctx.unfold) root.ctx.unfold(root.block.index) }
}
