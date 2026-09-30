import QtQuick
import qs.services

// One Nerd Font icon (octicons live at U+F400–U+F533).
Text {
  property real size: Reading.chrome
  textFormat: Text.PlainText
  font.family: "JetBrainsMono Nerd Font"
  font.pixelSize: size
  color: Theme.dim
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
