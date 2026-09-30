import QtQuick
import qs.Commons
import qs.services
import "../lib/inline.js" as Inline

// Selectable, read-only rich text for one piece of a block: inline runs
// from lib/inline.js painted in the theme, at a fixed line height.
TextEdit {
  id: root
  property var runs: []
  property real size: Reading.body
  property real leading: Reading.lineHeight
  property string family: Reading.prose
  // iA Writer Quattro S Bold declares a regular weight, so Qt would pick it
  // for plain text; naming the style keeps body text Regular (decision 0003).
  property string styleName: "Regular"
  property color baseColor: Theme.text
  property real tracking: 0
  property bool capitals: false

  readonly property real lineHeightPx: Math.round(size * leading)
  // Where the first line's glyphs sit, for things aligned to it (bullets,
  // heading anchors).
  property real firstLineY: 0

  readonly property string html: Inline.toHtml(runs, Reading.tones, { hover: hoveredLink })

  readOnly: true
  selectByMouse: true
  selectByKeyboard: false
  activeFocusOnPress: false
  wrapMode: TextEdit.Wrap
  textFormat: TextEdit.RichText
  color: baseColor
  selectionColor: Theme.selection
  selectedTextColor: Theme.text
  font.family: family
  font.styleName: styleName
  font.pixelSize: size
  font.letterSpacing: tracking
  font.capitalization: capitals ? Font.AllUppercase : Font.MixedCase
  text: "<p style=\"line-height:" + lineHeightPx + "px; margin:0\">" + html + "</p>"

  onImplicitHeightChanged: firstLineY = positionToRectangle(0).y

  HoverHandler {
    cursorShape: root.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
  }
}
