import QtQuick
import qs.Commons
import qs.services
import qs.components
import "../../lib/inline.js" as Inline

RichText {
  required property var block
  html: Inline.toHtml(block.runs, Reading.tones)
}
