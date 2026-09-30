import QtQuick
import qs.Commons
import qs.services

// A small rounded value: status, date, tag. `tone` colours it; a neutral
// pill is a hairline and the dim tier.
Rectangle {
  id: root
  property string text: ""
  property string icon: ""
  property color tone: "transparent"
  readonly property bool neutral: tone.a === 0
  property real size: Math.round(Reading.body * 0.76)

  implicitWidth: row.implicitWidth + Math.round(size * 1.3)
  implicitHeight: Math.round(size * 2)
  radius: height / 2
  color: neutral ? Theme.raised : Util.alpha(tone, Theme.light ? 0.12 : 0.14)
  border.width: 1
  border.color: neutral ? Theme.hairline : Util.alpha(tone, Theme.light ? 0.4 : 0.35)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Math.round(root.size * 0.4)
    Text {
      visible: root.icon !== ""
      text: root.icon
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: root.size
      color: root.neutral ? Theme.faint : root.tone
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: root.text
      textFormat: Text.PlainText
      color: root.neutral ? Theme.dim : Theme.mix(root.tone, Theme.text, Theme.light ? 0.25 : 0.1)
      font.family: Reading.mono
      font.pixelSize: root.size
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
