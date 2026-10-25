import QtQuick
import qs.Commons
import qs.Ui
import qs.services

// The word in the margin that says what happened to a block: "added",
// "removed" or "reworded", as a small tinted pill (MarkdownView.changes).
// When the margin is too narrow for the word (`room`), a dot in the same
// tone stands in and the word moves to its tooltip.
Rectangle {
  id: root
  property string change: ""
  property real room: 1e9
  readonly property bool quiet: change === "reworded" || change === "unchanged"
  readonly property color tone: change === "added" ? Theme.green : change === "removed" ? Theme.red : Theme.dim
  readonly property real pillWidth: label.implicitWidth + Math.round(Style.font.caption * 1.3)
  readonly property bool dot: room < pillWidth
  readonly property real dotSize: Math.round(Style.font.caption * 0.7)
  visible: change !== "" && change !== "same"

  implicitHeight: dot ? dotSize : Math.round(Style.font.caption * 1.75)
  implicitWidth: dot ? dotSize : pillWidth
  radius: height / 2
  color: dot ? Util.alpha(tone, quiet ? 0.55 : 0.85) : Util.alpha(tone, quiet ? (Theme.light ? 0.08 : 0.1) : (Theme.light ? 0.13 : 0.16))

  HoverHandler { id: hover; enabled: root.dot }
  PanelToolTip { visible: root.dot && hover.hovered; text: root.change }

  Text {
    id: label
    visible: !root.dot
    anchors.centerIn: parent
    text: root.change
    textFormat: Text.PlainText
    color: root.change === "unchanged" ? Theme.faint : root.quiet ? Theme.dim : Theme.mix(root.tone, Theme.text, Theme.light ? 0.25 : 0.2)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 0.3
  }
}
