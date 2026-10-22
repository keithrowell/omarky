import QtQuick
import qs.Commons
import qs.services
import qs.components
import "../../lib/inline.js" as Inline

// A real grid: a tinted header band in small mono capitals, hairline rules,
// generous padding, alignment from the separator row, tabular figures and
// faint zebra rows. Columns take their natural width up to a cap and wrap
// past it; a table wider than the column scrolls inside its frame, with a
// fade at the edge that has more.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property real textSize: Math.round(Reading.body * 0.94)
  readonly property real headSize: Math.round(Reading.body * 0.72)
  readonly property real padX: Math.round(Reading.body * 0.85)
  readonly property real padY: Math.round(Reading.body * 0.55)
  readonly property real maxCol: Math.round(textMetrics.averageCharacterWidth * 34)
  readonly property int cols: block.header.length

  function align(c) {
    var a = block.aligns[c]
    if (a === "center") return Text.AlignHCenter
    if (a === "right" || (a === "" && block.numeric[c])) return Text.AlignRight
    return Text.AlignLeft
  }

  // Column widths: each column's natural width (its widest cell), capped.
  // If that is wider than the page, columns give up space in proportion to
  // what they have beyond their minimum (the header, or ~10 characters), so
  // prose tables wrap to fit; only when even the minimums do not fit does
  // the table scroll sideways.
  readonly property var natural: {
    var out = []
    for (var c = 0; c < cols; c++) {
      var w = headMetrics.advanceWidth(Inline.plain(block.header[c]).toUpperCase())
      for (var r = 0; r < block.rows.length; r++) w = Math.max(w, cellWidth(block.rows[r][c]))
      out.push(Math.ceil(Math.min(w, maxCol) + padX * 2 + 2))
    }
    return out
  }
  readonly property var minimum: {
    var out = []
    for (var c = 0; c < cols; c++) {
      var head = headMetrics.advanceWidth(Inline.plain(block.header[c]).toUpperCase().split(/\s+/).reduce(function(a, b) { return a.length > b.length ? a : b }, ""))
      out.push(Math.ceil(Math.min(natural[c], Math.max(head + padX * 2 + 2, textMetrics.averageCharacterWidth * 10 + padX * 2))))
    }
    return out
  }
  readonly property var widths: {
    var avail = width - 2
    var total = natural.reduce(function(a, b) { return a + b }, 0)
    if (total <= avail || avail <= 0) return natural
    var minTotal = minimum.reduce(function(a, b) { return a + b }, 0)
    // Too wide either way: scroll, at a comfortable width per column.
    if (minTotal >= avail) {
      var cap = textMetrics.averageCharacterWidth * 24 + padX * 2
      return natural.map(function(n, c) { return Math.ceil(Math.max(minimum[c], Math.min(n, cap))) })
    }
    var give = total - avail, slack = total - minTotal
    return natural.map(function(n, c) { return Math.floor(n - (n - minimum[c]) * give / slack) })
  }
  readonly property real naturalWidth: widths.reduce(function(a, b) { return a + b }, 0)

  // Each run in the font it is drawn in; code chips add their padding.
  function cellWidth(runs) {
    var w = 0
    for (var i = 0; i < runs.length; i++) {
      var r = runs[i]
      if (r.code) w += codeMetrics.advanceWidth(r.t) + textMetrics.advanceWidth("\u2005\u2005")
      else w += (r.b ? boldMetrics : textMetrics).advanceWidth(r.t)
    }
    return w * 1.02 + 1
  }

  implicitHeight: frame.height
  implicitWidth: Math.min(naturalWidth, width)

  FontMetrics { id: textMetrics; font.family: Reading.prose; font.styleName: "Regular"; font.pixelSize: root.textSize }
  FontMetrics { id: boldMetrics; font.family: Reading.prose; font.styleName: "Bold"; font.pixelSize: root.textSize }
  FontMetrics { id: codeMetrics; font.family: Reading.mono; font.pixelSize: Reading.tones.codeSize }
  FontMetrics { id: headMetrics; font.family: Reading.mono; font.styleName: "Bold"; font.pixelSize: root.headSize; font.letterSpacing: 0.8 }

  Rectangle {
    id: frame
    width: Math.min(root.naturalWidth + 2, root.width)
    height: grid.height + 2
    radius: Math.max(4, Style.cornerRadius)
    color: "transparent"
    border.width: 1
    border.color: Theme.hairline
    clip: true

    Flickable {
      id: flick
      x: 1; y: 1
      width: parent.width - 2
      height: grid.height
      contentWidth: grid.width
      contentHeight: grid.height
      interactive: false
      clip: true

      Column {
        id: grid
        width: root.naturalWidth

        // ---- header band
        Rectangle {
          width: grid.width
          height: headRow.height
          color: Theme.raised
          Row {
            id: headRow
            Repeater {
              model: root.cols
              Item {
                required property int index
                width: root.widths[index]
                height: head.implicitHeight + root.padY * 2
                RichText {
                  id: head
                  x: root.padX
                  y: root.padY
                  width: parent.width - root.padX * 2
                  runs: [{ t: Inline.plain(root.block.header[index]) }]
                  ctx: root.ctx
                  pid: root.block.headerPids ? root.block.headerPids[index] : -1
                  horizontalAlignment: root.align(index)
                  baseColor: Theme.dim
                  family: Reading.mono
                  styleName: "Bold"
                  size: root.headSize
                  leading: 1.35
                  tracking: 0.8
                  capitals: true
                }
              }
            }
          }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hairline }
        }

        // ---- body rows
        Repeater {
          model: root.block.rows
          Rectangle {
            id: rowItem
            required property var modelData
            required property int index
            width: grid.width
            height: cells.height
            color: index % 2 === 1 ? Util.alpha(Theme.fg, Theme.light ? 0.022 : 0.018) : "transparent"

            Row {
              id: cells
              Repeater {
                model: root.cols
                Item {
                  required property int index
                  width: root.widths[index]
                  height: cellText.implicitHeight + root.padY * 2
                  RichText {
                    id: cellText
                    x: root.padX
                    y: root.padY
                    width: parent.width - root.padX * 2
                    runs: rowItem.modelData[index]
                    ctx: root.ctx
                    pid: root.block.rowPids ? root.block.rowPids[rowItem.index][index] : -1
                    size: root.textSize
                    leading: 1.45
                    horizontalAlignment: root.align(index)
                    font.features: root.block.numeric[index] ? { "tnum": 1 } : {}
                  }
                }
              }
            }
            Rectangle {
              visible: rowItem.index < root.block.rows.length - 1
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: Theme.hairlineSoft
            }
          }
        }
      }
    }

    WheelHandler {
      target: null
      enabled: flick.contentWidth > flick.width
      orientation: Qt.Horizontal
      onWheel: event => {
        flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - event.angleDelta.x / 2))
      }
    }

    // Fades mark the edges that have more.
    Rectangle {
      visible: flick.contentX > 1
      x: 1; y: 1
      width: Math.round(Reading.body * 2.2); height: parent.height - 2
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.bg }
        GradientStop { position: 1; color: Util.alpha(Theme.bg, 0) }
      }
    }
    Rectangle {
      visible: flick.contentWidth > flick.width + 1 && flick.contentX < flick.contentWidth - flick.width - 1
      x: parent.width - width - 1; y: 1
      width: Math.round(Reading.body * 2.8); height: parent.height - 2
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Util.alpha(Theme.bg, 0) }
        GradientStop { position: 1; color: Theme.bg }
      }
    }
  }
}
