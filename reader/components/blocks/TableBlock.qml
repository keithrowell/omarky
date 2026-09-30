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

  // Natural width of each column, from its widest cell, capped.
  readonly property var widths: {
    var out = []
    for (var c = 0; c < cols; c++) {
      var w = headMetrics.advanceWidth(Inline.plain(block.header[c]).toUpperCase())
      for (var r = 0; r < block.rows.length; r++) {
        var cell = block.rows[r][c]
        var t = Inline.plain(cell)
        var bold = cell.some(function(x) { return x.b })
        w = Math.max(w, (bold ? boldMetrics : textMetrics).advanceWidth(t) * 1.02)
      }
      out.push(Math.ceil(Math.min(w, maxCol) + padX * 2 + 2))
    }
    return out
  }
  readonly property real naturalWidth: widths.reduce(function(a, b) { return a + b }, 0)

  implicitHeight: frame.height
  implicitWidth: Math.min(naturalWidth, width)

  FontMetrics { id: textMetrics; font.family: Reading.prose; font.styleName: "Regular"; font.pixelSize: root.textSize }
  FontMetrics { id: boldMetrics; font.family: Reading.prose; font.styleName: "Bold"; font.pixelSize: root.textSize }
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
                Text {
                  id: head
                  x: root.padX
                  y: root.padY
                  width: parent.width - root.padX * 2
                  text: Inline.plain(root.block.header[index])
                  textFormat: Text.PlainText
                  wrapMode: Text.Wrap
                  horizontalAlignment: root.align(index)
                  color: Theme.dim
                  font.family: Reading.mono
                  font.styleName: "Bold"
                  font.pixelSize: root.headSize
                  font.letterSpacing: 0.8
                  font.capitalization: Font.AllUppercase
                  lineHeight: 1.3
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
