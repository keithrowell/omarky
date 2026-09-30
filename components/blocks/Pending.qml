import QtQuick
import qs.services

// Stand-in while a block type is being built.
Text {
  required property var block
  property var ctx: null
  property var look: ({})
  text: "[" + block.type + "]"
  color: Theme.faint
  font.family: Reading.mono
  font.pixelSize: Reading.body
}
