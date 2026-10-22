import QtQuick
import qs.Commons
import qs.services

// A keyboard key: "Ctrl+F", "g g", "?".
Rectangle {
  id: root
  property string keys: ""
  implicitWidth: label.implicitWidth + Style.space(12)
  implicitHeight: label.implicitHeight + Style.space(6)
  radius: Math.max(3, Style.cornerRadius - 2)
  color: Theme.raised
  border.width: 1
  border.color: Theme.hairline

  Text {
    id: label
    anchors.centerIn: parent
    text: root.keys
    textFormat: Text.PlainText
    color: Theme.dim
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
