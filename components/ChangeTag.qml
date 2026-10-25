import QtQuick
import qs.Commons
import qs.services

// The word in the margin that says what happened to a block: "added",
// "removed" or "reworded", as a small tinted pill (MarkdownView.changes).
Rectangle {
  id: root
  property string change: ""
  readonly property bool quiet: change === "reworded" || change === "unchanged"
  readonly property color tone: change === "added" ? Theme.green : change === "removed" ? Theme.red : Theme.dim
  visible: change !== "" && change !== "same"

  implicitHeight: Math.round(Style.font.caption * 1.75)
  implicitWidth: label.implicitWidth + Math.round(Style.font.caption * 1.3)
  radius: height / 2
  color: Util.alpha(tone, quiet ? (Theme.light ? 0.08 : 0.1) : (Theme.light ? 0.13 : 0.16))

  Text {
    id: label
    anchors.centerIn: parent
    text: root.change
    textFormat: Text.PlainText
    color: root.change === "unchanged" ? Theme.faint : root.quiet ? Theme.dim : Theme.mix(root.tone, Theme.text, Theme.light ? 0.25 : 0.2)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 0.3
  }
}
