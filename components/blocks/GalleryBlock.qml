import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.services
import qs.components

// Images from HTML that is nothing but <img> tags (docs/decisions/0002):
// laid out in centred rows that wrap, each at its HTML height or width
// (CSS px, following zoom) or else its natural size up to a cap. Never
// wider than the column. Local paths resolve against the file; a missing
// image becomes a small placeholder tile with its alt text as a tooltip.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property real cssPx: Reading.body / 16
  readonly property real gap: Math.round(Reading.body * 0.5)
  readonly property real capH: Math.round(Reading.body * 16)
  // Bumped when an image's natural size arrives, so the rows relayout.
  property int loaded: 0

  // The shown size of item i given its natural size (0 while unknown).
  function sizeOf(i, natW, natH) {
    var it = block.items[i]
    var aspect = natW > 0 && natH > 0 ? natW / natH : 0.75
    var w, h
    if (it.h) { h = it.h * cssPx; w = h * aspect }
    else if (it.w) { w = it.w * cssPx; h = w / aspect }
    else { h = natH > 0 ? Math.min(natH, capH) : Math.round(Reading.body * 10); w = h * aspect }
    if (w > width) { h = h * width / w; w = width }
    return { w: Math.round(w), h: Math.round(h) }
  }

  // Greedy rows, each centred: [{ x, y, w, h }] plus the total height.
  readonly property var layout: {
    loaded
    var tiles = repeater.count === block.items.length ? [] : null
    if (!tiles || width <= 0) return { boxes: [], height: 0 }
    var sizes = []
    for (var i = 0; i < block.items.length; i++) {
      var t = repeater.itemAt(i)
      sizes.push(sizeOf(i, t ? t.natW : 0, t ? t.natH : 0))
    }
    var boxes = [], rows = [], row = [], rowW = 0
    for (var j = 0; j < sizes.length; j++) {
      var add = (row.length ? gap : 0) + sizes[j].w
      if (row.length && rowW + add > width) { rows.push({ items: row, w: rowW }); row = []; rowW = 0; add = sizes[j].w }
      row.push(j); rowW += add
    }
    if (row.length) rows.push({ items: row, w: rowW })
    var y = 0
    for (var r = 0; r < rows.length; r++) {
      var x = Math.round((width - rows[r].w) / 2), rowH = 0
      for (var k = 0; k < rows[r].items.length; k++) {
        var n = rows[r].items[k], s = sizes[n]
        boxes[n] = { x: x, y: y, w: s.w, h: s.h }
        x += s.w + gap
        rowH = Math.max(rowH, s.h)
      }
      // Shorter images in a row sit on its baseline.
      for (var q = 0; q < rows[r].items.length; q++) boxes[rows[r].items[q]].y = y + rowH - sizes[rows[r].items[q]].h
      y += rowH + (r < rows.length - 1 ? gap : 0)
    }
    return { boxes: boxes, height: y }
  }

  implicitHeight: layout.height

  Repeater {
    id: repeater
    model: root.block.items

    Item {
      id: tile
      required property var modelData
      required property int index
      readonly property var box: root.layout.boxes[index] || ({ x: 0, y: 0, w: 0, h: 0 })
      readonly property string url: root.ctx ? root.ctx.resolveUrl(modelData.src) : modelData.src
      readonly property bool local: url.indexOf("file://") === 0
      // Local files are checked first: a missing one must not reach Image,
      // which would log a warning.
      property bool found: !local
      property bool checked: !local
      readonly property bool failed: img.status === Image.Error || (checked && !found)
      readonly property bool ready: img.status === Image.Ready
      readonly property real natW: ready ? img.implicitWidth : 0
      readonly property real natH: ready ? img.implicitHeight : 0
      onReadyChanged: root.loaded++

      x: box.x; y: box.y; width: box.w; height: box.h

      Image {
        id: img
        visible: tile.ready
        anchors.fill: parent
        source: tile.found ? tile.url : ""
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
      }
      CornerMask {
        visible: tile.ready
        anchors.fill: parent
        radius: Math.max(4, Style.cornerRadius)
        color: root.look.surface || Theme.bg
      }

      // Loading or missing.
      Rectangle {
        visible: !tile.ready
        anchors.fill: parent
        radius: Math.max(4, Style.cornerRadius)
        color: Theme.card
        border.width: 1
        border.color: Theme.hairline
        Text {
          anchors.centerIn: parent
          text: tile.failed ? "" : ""
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: Math.round(Reading.body * 1.05)
          color: Theme.faint
        }
      }

      HoverHandler { id: hover }
      PanelToolTip {
        visible: hover.hovered && text !== ""
        text: tile.failed ? "Image not found · " + tile.modelData.src : (tile.modelData.alt || tile.modelData.title)
      }

      Process {
        running: tile.local
        command: ["test", "-r", decodeURI(tile.url.slice(7))]
        onExited: code => { tile.found = code === 0; tile.checked = true }
      }
    }
  }
}
