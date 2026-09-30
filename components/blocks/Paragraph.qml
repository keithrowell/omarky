import QtQuick
import qs.services
import qs.components

RichText {
  required property var block
  property var ctx: null
  property var look: ({})
  runs: block.runs
  size: look.size || Reading.body
  baseColor: look.tier === "dim" ? Theme.dim : Theme.text
}
