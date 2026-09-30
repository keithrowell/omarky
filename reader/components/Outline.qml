import QtQuick
import qs.Commons
import qs.services

// The heading tree. The section being read is marked (scroll-spy) and kept
// in view; clicking a heading asks the view to glide there.
Rectangle {
  id: root
  property var headings: []
  // Index into `headings` of the section at the top of the page.
  property int current: -1
  signal jump(int blockIndex)

  // h1–h4; indent relative to the shallowest level present.
  readonly property var items: headings.filter(function(h) { return h.level <= 4 })
  readonly property int minLevel: items.reduce(function(m, h) { return Math.min(m, h.level) }, 6)
  readonly property int currentItem: {
    if (current < 0) return -1
    var target = headings[current]
    var best = -1
    for (var i = 0; i < items.length; i++) if (items[i].index <= target.index) best = i
    return best
  }

  color: Util.alpha(Theme.fg, Theme.light ? 0.025 : 0.02)

  Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.hairlineSoft }

  Text {
    id: title
    x: Style.space(20)
    y: Style.space(18)
    text: "Contents"
    textFormat: Text.PlainText
    color: Theme.faint
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
    font.capitalization: Font.AllUppercase
  }

  ListView {
    id: list
    anchors.top: title.bottom
    anchors.topMargin: Style.space(10)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(12)
    width: parent.width - 1
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: root.items
    currentIndex: root.currentItem
    highlightFollowsCurrentItem: false
    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: Item {
      id: entry
      required property var modelData
      required property int index
      readonly property bool isCurrent: index === root.currentItem
      readonly property int depth: modelData.level - root.minLevel
      width: list.width
      height: label.implicitHeight + Style.space(9)

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        radius: Math.max(3, Style.cornerRadius - 2)
        color: hover.hovered ? Theme.hover : entry.isCurrent ? Util.alpha(Theme.accent, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: Reading.motion(120) } }
      }

      Rectangle {
        visible: entry.isCurrent
        x: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: label.implicitHeight
        radius: 1
        color: Theme.accent
      }

      Text {
        id: label
        x: Style.space(20) + entry.depth * Style.space(12)
        width: parent.width - x - Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        text: entry.modelData.text || "—"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: entry.isCurrent ? Theme.text : entry.depth === 0 ? Theme.dim : Theme.faint
        font.family: Style.font.family
        font.pixelSize: entry.depth === 0 ? Style.font.bodySmall : Style.font.caption
        font.bold: entry.depth === 0
        Behavior on color { ColorAnimation { duration: Reading.motion(120) } }
      }

      HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.jump(entry.modelData.index) }
    }
  }
}
