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

  // ---- inline-code chips drawn under the text, and change marks: a wash
  // under inserted text, a strike over removed text (rich text cannot
  // colour a strike apart from its text, so both are drawn here).
  readonly property var chipSpans: Inline.chipRanges(runs)
  readonly property var markSpans: Inline.markRanges(runs)
  property var chips: []
  property var marks: []
  readonly property real chipH: Math.round(Reading.tones.codeSize * 1.5)
  readonly property real washH: Math.round(size * 1.3)

  // Each span as one rectangle per line it covers. Spans are [a, b] pairs
  // (chips) or { a, b, kind } (marks).
  function piecesOf(spans) {
    var out = []
    for (var i = 0; i < spans.length; i++) {
      var sp = spans[i]
      var a = sp.a !== undefined ? sp.a : sp[0], b = sp.b !== undefined ? sp.b : sp[1], kind = sp.kind || ""
      var ra = positionToRectangle(a), rb = positionToRectangle(b)
      var from = a
      // A span that wraps becomes one piece per line.
      while (ra.y < rb.y - 1) {
        var k = from + 1
        while (k < b && positionToRectangle(k).y <= ra.y + 1) k++
        var rEnd = positionToRectangle(k - 1)
        var w = rEnd.x + (rEnd.x < ra.x ? 0 : size * 0.55) - ra.x
        out.push({ x: ra.x, y: ra.y, w: Math.max(4, w), kind: kind })
        from = k
        ra = positionToRectangle(k)
      }
      out.push({ x: ra.x, y: ra.y, w: Math.max(4, rb.x - ra.x), kind: kind })
    }
    return out
  }

  function layoutChips() { chips = chipSpans.length ? piecesOf(chipSpans) : [] }
  function layoutMarks() { marks = markSpans.length ? piecesOf(markSpans) : [] }
  function relayout() { layoutChips(); layoutMarks() }

  // Laid out once the text has settled. A Timer, not Qt.callLater: the
  // timer dies with the item, so a delegate recycled mid-frame never runs
  // a layout on a dead object.
  Timer { id: relayoutTimer; interval: 0; onTriggered: root.relayout() }
  onChipSpansChanged: relayoutTimer.restart()
  onMarkSpansChanged: relayoutTimer.restart()
  onWidthChanged: if (chipSpans.length || markSpans.length) relayoutTimer.restart()
  onTextChanged: if (chipSpans.length || markSpans.length) relayoutTimer.restart()

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

  Repeater {
    model: root.marks
    Rectangle {
      required property var modelData
      readonly property bool ins: modelData.kind === "ins"
      z: ins ? -1 : 1
      x: Math.round(modelData.x) - (ins ? 2 : 0)
      y: ins ? Math.round(modelData.y + root.washOffset) : Math.round(modelData.y + root.strikeOffset)
      width: Math.round(modelData.w) + (ins ? 4 : 0)
      height: ins ? root.washH : Math.max(1, Math.round(root.size / 11))
      radius: ins ? 3 : 0
      color: ins ? Reading.tones.ins : Reading.tones.delLine
    }
  }

  onLinkActivated: link => { if (ctx) ctx.openLink(link) }
  onImplicitHeightChanged: firstLineY = positionToRectangle(0).y
  // Centre chips on the x-height of their line.
  FontMetrics { id: chipMetrics; font.family: root.family; font.styleName: "Regular"; font.pixelSize: root.size }
  readonly property real chipOffset: Math.round(chipMetrics.ascent - chipMetrics.xHeight / 2 - chipH / 2)
  readonly property real washOffset: Math.round(chipMetrics.ascent - chipMetrics.xHeight / 2 - washH / 2)
  readonly property real strikeOffset: Math.round(chipMetrics.ascent - chipMetrics.xHeight * 0.5)

  HoverHandler {
    cursorShape: root.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
  }
}
