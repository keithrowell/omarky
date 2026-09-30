import QtQuick
import qs.Commons
import qs.services
import "../lib/inline.js" as Inline

// Selectable, read-only rich text for one piece of a block: inline runs
// from lib/inline.js painted in the theme, at a fixed line height.
TextEdit {
  id: root
  property var runs: []
  // The window's context (links, copy); set by the block that owns this.
  property var ctx: null
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

  // Find: this piece's id (lib/blocks.js stampPieces) ties it to matches.
  property int pid: -1
  readonly property var finder: ctx ? ctx.finder : null
  readonly property string findQuery: finder && pid >= 0 ? finder.query : ""
  readonly property bool holdsCurrent: finder !== null && pid >= 0 && finder.currentPid === pid
  readonly property int currentK: holdsCurrent ? finder.currentK : -1

  readonly property string html: Inline.toHtml(runs, Reading.tones, {
    hover: hoveredLink, find: findQuery, findBg: Reading.tones.findBg,
    current: currentK, currentBg: Reading.tones.currentBg, currentText: Reading.tones.currentText
  })

  function revealCurrent() {
    if (currentK < 0 || !ctx) return
    var ranges = Inline.matchRanges(Inline.plain(runs), findQuery)
    if (currentK >= ranges.length) return
    var r = positionToRectangle(Inline.docPos(runs, ranges[currentK][0]))
    ctx.revealMatch(root, r.y + r.height / 2)
  }
  onCurrentKChanged: if (currentK >= 0) Qt.callLater(revealCurrent)
  Component.onCompleted: if (currentK >= 0) Qt.callLater(revealCurrent)

  onSelectedTextChanged: if (selectedText && ctx) ctx.claimSelection(root)

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
  // pre-wrap: the chip padding spaces must not collapse into neighbours.
  text: "<p style=\"line-height:" + lineHeightPx + "px; margin:0; white-space:pre-wrap\">" + html + "</p>"

  // ---- inline-code chips, drawn under the text
  readonly property var chipSpans: Inline.chipRanges(runs)
  property var chips: []
  readonly property real chipH: Math.round(Reading.tones.codeSize * 1.5)

  function layoutChips() {
    if (!chipSpans.length) { if (chips.length) chips = []; return }
    var out = []
    for (var i = 0; i < chipSpans.length; i++) {
      var a = chipSpans[i][0], b = chipSpans[i][1]
      var ra = positionToRectangle(a), rb = positionToRectangle(b)
      var from = a
      // A chip that wraps becomes one piece per line.
      while (ra.y < rb.y - 1) {
        var k = from + 1
        while (k < b && positionToRectangle(k).y <= ra.y + 1) k++
        var rEnd = positionToRectangle(k - 1)
        var w = rEnd.x + (positionToRectangle(k - 1).x < ra.x ? 0 : Reading.tones.codeSize * 0.6) - ra.x
        out.push({ x: ra.x, y: ra.y, w: Math.max(4, w) })
        from = k
        ra = positionToRectangle(k)
      }
      out.push({ x: ra.x, y: ra.y, w: Math.max(4, rb.x - ra.x) })
    }
    chips = out
  }

  onChipSpansChanged: Qt.callLater(layoutChips)
  onWidthChanged: if (chipSpans.length) Qt.callLater(layoutChips)
  onTextChanged: if (chipSpans.length) Qt.callLater(layoutChips)

  Repeater {
    model: root.chips
    Rectangle {
      required property var modelData
      z: -1
      x: Math.round(modelData.x)
      y: Math.round(modelData.y + root.chipOffset)
      width: Math.round(modelData.w)
      height: root.chipH
      radius: Math.max(3, Math.round(root.chipH * 0.22))
      color: Theme.chipFill
      border.width: 1
      border.color: Theme.chipEdge
    }
  }

  onLinkActivated: link => { if (ctx) ctx.openLink(link) }
  onImplicitHeightChanged: firstLineY = positionToRectangle(0).y
  // Centre chips on the x-height of their line.
  FontMetrics { id: chipMetrics; font.family: root.family; font.styleName: "Regular"; font.pixelSize: root.size }
  readonly property real chipOffset: Math.round(chipMetrics.ascent - chipMetrics.xHeight / 2 - chipH / 2)

  HoverHandler {
    cursorShape: root.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
  }
}
