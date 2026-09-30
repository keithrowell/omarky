import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.services
import qs.components

// Bullets and numbers hang in the margin so item text aligns with the
// paragraph; nested levels step in with a lighter bullet. Task items get a
// drawn, read-only checkbox and dimmed text once done.
Column {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property real textSize: look.size || Reading.body
  readonly property real lineH: Math.round(textSize * Reading.lineHeight)
  readonly property real markerGap: Math.round(textSize * 0.55)
  readonly property real markerWidth: {
    var w = textSize * 0.9
    if (block.ordered) w = numbers.advanceWidth(String(block.start + block.items.length - 1) + ".")
    if (block.tasks) w = Math.max(w, box)
    return Math.ceil(w)
  }
  // Top-level markers hang left of the column; nested lists step in.
  // Inside a card or quote there is no margin to hang in.
  readonly property real indent: block.depth > 0 || look.contained ? Math.max(markerWidth + markerGap, Math.round(textSize * 1.5)) : 0
  readonly property real box: Math.round(textSize * 0.9)

  spacing: block.tight ? Math.round(textSize * 0.3) : Math.round(textSize * 0.75)

  // Where glyphs sit inside a fixed-height rich-text line: markers centre
  // on the x-height of the first line, measured rather than guessed.
  RichText { id: probe; visible: false; width: 100; runs: [{ t: "x" }]; size: root.textSize }
  FontMetrics { id: probeMetrics; font.family: Reading.prose; font.styleName: "Regular"; font.pixelSize: root.textSize }
  readonly property real xCentre: probe.firstLineY + probeMetrics.ascent - probeMetrics.xHeight / 2

  FontMetrics { id: numbers; font.family: Reading.prose; font.styleName: "Regular"; font.pixelSize: root.textSize }

  Repeater {
    model: root.block.items

    Item {
      id: item
      required property var modelData
      required property int index
      readonly property bool done: modelData.task === "done"
      width: root.width
      height: body.height

      // ---- marker, hung in the margin and centred on the first line
      Item {
        id: marker
        x: root.indent - root.markerGap - width
        width: root.markerWidth
        height: root.lineH

        // Bullets: a dot, then a ring, then a short dash, each lighter.
        Rectangle {
          visible: !root.block.ordered && item.modelData.task === "" && root.block.depth % 3 !== 2
          readonly property real d: Math.round(root.textSize * (root.block.depth % 3 === 0 ? 0.3 : 0.32))
          width: d; height: d; radius: d / 2
          anchors.right: parent.right
          anchors.rightMargin: Math.round(root.textSize * 0.12)
          y: Math.round(root.xCentre - height / 2)
          color: root.block.depth % 3 === 0 ? Theme.dim : "transparent"
          border.width: root.block.depth % 3 === 1 ? Math.max(1, Math.round(root.textSize / 14)) : 0
          border.color: Theme.faint
        }
        Rectangle {
          visible: !root.block.ordered && item.modelData.task === "" && root.block.depth % 3 === 2
          width: Math.round(root.textSize * 0.36); height: Math.max(1, Math.round(root.textSize / 12))
          radius: height / 2
          anchors.right: parent.right
          anchors.rightMargin: Math.round(root.textSize * 0.1)
          y: Math.round(root.xCentre - height / 2)
          color: Theme.faint
        }

        // Same line box as the item text, so the baselines match.
        RichText {
          visible: root.block.ordered && item.modelData.task === ""
          width: parent.width
          horizontalAlignment: TextEdit.AlignRight
          selectByMouse: false
          runs: [{ t: item.modelData.number + "." }]
          size: root.textSize
          baseColor: Theme.faint
          font.features: { "tnum": 1 }
        }

        // Task checkbox.
        Rectangle {
          visible: item.modelData.task !== ""
          width: root.box; height: root.box
          anchors.right: parent.right
          y: Math.round(root.xCentre - height / 2 - root.textSize * 0.04)
          radius: Math.max(2, Math.round(root.box * 0.24))
          color: item.done ? Theme.accent : "transparent"
          border.width: item.done ? 0 : Math.max(1, Math.round(root.textSize / 12))
          border.color: Theme.faint

          Shape {
            visible: item.done
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeColor: Theme.bg
              strokeWidth: Math.max(1.5, root.box / 7)
              fillColor: "transparent"
              capStyle: ShapePath.RoundCap
              joinStyle: ShapePath.RoundJoin
              startX: root.box * 0.26; startY: root.box * 0.53
              PathLine { x: root.box * 0.43; y: root.box * 0.7 }
              PathLine { x: root.box * 0.75; y: root.box * 0.32 }
            }
          }
        }
      }

      BlockStack {
        id: body
        x: root.indent
        width: parent.width - root.indent
        blocks: item.modelData.blocks
        ctx: root.ctx
        tight: root.block.tight
        look: item.done ? Object.assign({}, root.look, { tier: "dim" }) : root.look
      }
    }
  }
}
