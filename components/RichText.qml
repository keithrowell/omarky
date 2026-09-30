import QtQuick
import qs.Commons
import qs.services

// Selectable, read-only rich text for one piece of a block. `html` is the
// inline markup from lib/inline.js; this wraps it with the line height.
TextEdit {
  id: root
  property string html: ""
  property real size: Reading.body
  property real leading: Reading.lineHeight
  property string family: Reading.prose

  readOnly: true
  selectByMouse: true
  selectByKeyboard: false
  activeFocusOnPress: false
  wrapMode: TextEdit.Wrap
  textFormat: TextEdit.RichText
  color: Theme.text
  selectionColor: Theme.selection
  selectedTextColor: Theme.text
  font.family: family
  // iA Writer Quattro S Bold declares a regular weight, so Qt would pick it
  // for plain text; naming the style keeps body text Regular (decision 0003).
  font.styleName: "Regular"
  font.pixelSize: size
  text: "<p style=\"line-height:" + Math.round(size * leading) + "px; margin:0\">" + html + "</p>"
}
