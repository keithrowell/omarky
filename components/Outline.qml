import QtQuick
import qs.Commons
import qs.services

// The heading tree. The section being read is shaded (scroll-spy) and kept
// in view; clicking a heading asks the view to glide there. In changes mode
// each section's change count sits at the right, and headings with nothing
// changed dim while the fold is on.
Rectangle {
  id: root
  property var headings: []
  // Index into `headings` of the section at the top of the page.
  property int current: -1
  // The shown blocks, for the change counts (headings carry sectionChanges).
  property var blocks: []
  property bool dimUnchanged: false
  signal jump(int blockIndex)

  function countAt(index) {
    var b = blocks[index]
    if (!b) return 0
    if (b.type === "fold" && b.heading) return 0
    return b.sectionChanges || 0
  }
  // Words inserted and removed in the section, for the mix bar.
  function mixAt(index) {
    var b = blocks[index]
    if (!b || (b.type === "fold" && b.heading)) return { ins: 0, del: 0 }
    return { ins: b.sectionIns || 0, del: b.sectionDel || 0 }
  }

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
      readonly property int n: root.countAt(modelData.index)
      readonly property var mix: root.mixAt(modelData.index)
      width: list.width
      height: label.implicitHeight + Style.space(12)

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        radius: Math.max(3, Style.cornerRadius - 2)
        color: hover.hovered ? Theme.hover : entry.isCurrent ? Util.alpha(Theme.accent, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: Reading.motion(120) } }
      }

      Text {
        id: label
        x: Style.space(22) + entry.depth * Style.space(14)
        width: parent.width - x - Style.space(18) - (count.visible ? count.width + mixBar.width + Style.space(14) : 0)
        anchors.verticalCenter: parent.verticalCenter
        text: entry.modelData.text || "Untitled"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: entry.isCurrent ? Theme.text : entry.depth === 0 ? Theme.dim : Theme.mix(Theme.dim, Theme.faint, 0.5)
        font.family: Style.font.family
        font.pixelSize: entry.depth === 0 ? Style.font.body : Style.font.bodySmall
        font.bold: entry.depth === 0
        opacity: root.dimUnchanged && entry.n === 0 ? 0.5 : 1
        Behavior on color { ColorAnimation { duration: Reading.motion(120) } }
      }

      // The mix: green for words added, red for words removed, as one
      // small bar after the count.
      Item {
        id: mixBar
        visible: entry.n > 0
        anchors.right: parent.right
        anchors.rightMargin: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(22)
        height: Style.space(4)
        readonly property int sum: entry.mix.ins + entry.mix.del
        readonly property real share: sum > 0 ? entry.mix.ins / sum : 0.5
        Rectangle { x: 0; width: Math.round(parent.width * parent.share); height: parent.height; radius: 2; color: Theme.flat(Theme.green, 0.8); visible: width > 0 }
        Rectangle { x: Math.round(parent.width * parent.share) + (parent.share > 0 && parent.share < 1 ? 1 : 0); width: parent.width - x; height: parent.height; radius: 2; color: Theme.flat(Theme.red, 0.75); visible: width > 0 }
      }
      Text {
        id: count
        anchors.right: mixBar.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        visible: entry.n > 0
        text: String(entry.n)
        textFormat: Text.PlainText
        color: entry.isCurrent ? Theme.text : Theme.dim
        font.family: Reading.mono
        font.pixelSize: Style.font.caption
        font.features: { "tnum": 1 }
      }

      HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.jump(entry.modelData.index) }
    }
  }
}
