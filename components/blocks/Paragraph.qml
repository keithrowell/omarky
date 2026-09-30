import QtQuick
import qs.services
import qs.components

RichText {
  id: root
  required property var block
  property var look: ({})
  runs: block.runs
  size: look.size || Reading.body
  baseColor: look.tier === "dim" ? Theme.dim : Theme.text
}
