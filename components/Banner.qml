import QtQuick
import qs.Commons
import qs.services

// A gentle strip under the header (the file was deleted, …).
Rectangle {
  id: root
  property string text: ""
  property color tone: Theme.yellow
  implicitHeight: Style.space(34)
  color: Util.alpha(tone, Theme.light ? 0.1 : 0.09)

  Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Util.alpha(root.tone, 0.25) }

  Row {
    anchors.centerIn: parent
    spacing: Style.space(8)
    Glyph { text: ""; size: Style.font.bodySmall; color: root.tone; anchors.verticalCenter: parent.verticalCenter }
    Text {
      text: root.text
      textFormat: Text.PlainText
      color: Theme.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
