import QtQuick
import qs.Commons
import qs.services

// The reading column: a ListView over the flat block list, one delegate per
// block (decision 0001), centred at a measure computed from the body
// font's metrics. Also owns scrolling: keys, anchors, find, scroll-spy and
// keeping the reading position across live reloads.
ListView {
  id: root
  property var blocks: []
  property bool wide: false
  property var ctx: null
  property var anchorMap: ({})
  property int lineCount: 1
  // Block under the mouse, for Ctrl+Shift+C.
  property int hoveredIndex: -1

  readonly property real measure: Math.round(bodyMetrics.averageCharacterWidth * (wide ? 100 : 68))
  readonly property real sideRoom: Math.max(Style.space(24), Math.min(Style.space(56), width * 0.06))
  readonly property real column: Math.max(Style.space(200), Math.min(measure, width - sideRoom * 2))
  readonly property real gutter: Math.round((width - column) / 2)
  readonly property real topRoom: Style.space(44)

  // First block at the top of the view, and how far we are through the file
  // (by source line, so it is smooth and exact even though the ListView
  // only estimates its content height).
  readonly property int topIndex: {
    if (count === 0 || contentY <= originY + 1) return 0
    // Probe a little below the top edge; gaps between blocks belong to the
    // block below them.
    for (var dy = Style.space(24); dy < height; dy += Style.space(24)) {
      var i = indexAt(width / 2, contentY + dy)
      if (i >= 0) return i
    }
    return count - 1
  }
  readonly property real progress: {
    if (count === 0) return 0
    if (atYEnd) return 1
    if (contentY <= originY + 1) return 0
    var b = blocks[Math.max(0, Math.min(topIndex, blocks.length - 1))]
    var byLine = b ? Math.max(0, Math.min(1, b.srcStart / Math.max(1, lineCount))) : 0
    // Over the last screen, ease the rest of the way to 1 by distance.
    var last = itemAtIndex(count - 1)
    if (!last) return byLine
    var remaining = last.y + last.height + (footerItem ? footerItem.height : 0) - (contentY + height)
    var t = Math.max(0, Math.min(1, 1 - remaining / height))
    return byLine + (1 - byLine) * t
  }

  FontMetrics { id: bodyMetrics; font.family: Reading.prose; font.styleName: "Regular"; font.pixelSize: Reading.body }

  model: blocks
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  // The wheel handler below owns every scroll gesture (decision 0011); the
  // Flickable's own wheel and drag handling would add a second, slower
  // movement on top of it.
  interactive: false
  cacheBuffer: Math.max(1600, height * 2)
  reuseItems: false
  header: Item { height: root.topRoom }
  footer: Item { height: Math.max(Style.space(120), root.height * 0.3) }

  // ---- scrolling

  function clampY(y) { return Math.max(originY, Math.min(y, originY + contentHeight - height)) }

  // Where contentY would be with block `index` at the top (less a margin).
  function targetFor(index) {
    var keep = contentY
    positionViewAtIndex(index, ListView.Beginning)
    var y = contentY
    contentY = keep
    return clampY(y - Style.space(20))
  }

  function glide(y, ms) {
    y = clampY(y)
    fling.stop()
    if (Reading.reducedMotion || ms === 0) { scrollAnim.stop(); contentY = y; return }
    scrollAnim.duration = ms
    scrollAnim.to = y
    scrollAnim.restart()
  }

  // Smooth travel to a place the ListView must first resolve (its content
  // height is only an estimate): far jumps cut to one screen short, then
  // glide the rest, so the landing is exact and the motion stays short.
  function travel(resolve) {
    scrollAnim.stop()
    fling.stop()
    var keep = contentY
    resolve()
    var target = contentY
    contentY = keep
    if (Reading.reducedMotion) { resolve(); return }
    if (Math.abs(target - keep) > height * 1.5) {
      contentY = target + (target > keep ? -height * 0.8 : height * 0.8)
      keep = contentY
      resolve()
      target = contentY
      contentY = keep
    }
    glide(target, 240)
  }

  function scrollToIndex(index, animated) {
    if (index < 0 || index >= count) return
    if (animated === false) { contentY = targetFor(index); return }
    travel(function() {
      positionViewAtIndex(index, ListView.Beginning)
      contentY = clampY(contentY - Style.space(20))
    })
  }

  function scrollToAnchor(name) {
    if (name in anchorMap) { scrollToIndex(anchorMap[name], true); return true }
    return false
  }

  // Keyboard scrolling continues from where an animation is heading.
  function scrollBy(dy) {
    var from = scrollAnim.running ? scrollAnim.to : contentY
    glide(from + dy, 110)
  }
  function lineStep() { return Math.round(Reading.body * Reading.lineHeight * 3) }
  function pageStep() { return Math.max(lineStep(), height - Style.space(80)) }
  function toTop() { travel(function() { positionViewAtBeginning() }) }
  function toBottom() { travel(function() { positionViewAtEnd() }) }

  // Screenshot driver: one screen, no animation; false at the end.
  function pageDown() {
    if (atYEnd) return false
    scrollAnim.stop()
    contentY = clampY(contentY + pageStep())
    return true
  }

  // Bring a spot inside a delegate (the current find match) into view.
  function reveal(item, localY) {
    var p = item.mapToItem(root.contentItem, 0, localY)
    if (p.y > contentY + height * 0.2 && p.y < contentY + height * 0.75) return
    glide(p.y - height * 0.35, 200)
  }

  NumberAnimation {
    id: scrollAnim
    target: root
    property: "contentY"
    duration: 260
    easing.type: Easing.OutCubic
  }

  // ---- touchpad and wheel (decision 0011)
  //
  // For a two-finger scroll the compositor sends a value per frame; Qt moves
  // a Flickable one logical pixel per unit, Chromium moves twelve and flings
  // when the fingers lift. This handler does what Chromium does, so a swipe
  // here travels as far as the same swipe in Helium. A mouse wheel notch
  // moves 120 px, smoothed, as it does there too.
  property real touchpadScroll: 12

  WheelHandler {
    id: wheel
    target: null
    // Wayland tags a finger scroll with the mouse device and only marks it
    // as synthesised; the TouchPad flag is what lets those events in.
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    property bool gesture: false
    property real lastT: 0
    // The last few frames of the gesture, as contentY deltas and the time
    // each took, for the fling velocity.
    property var samples: []

    onWheel: event => {
      var now = Date.now()
      var dy = event.pixelDelta.y
      if (dy !== 0) {
        if (!gesture) {
          gesture = true
          fling.stop()
          scrollAnim.stop()
          samples = []
          lastT = now
        }
        var d = -dy * root.touchpadScroll
        root.contentY = root.clampY(root.contentY + d)
        samples = samples.concat([{ d: d, dt: Math.max(1, now - lastT) }]).slice(-3)
        lastT = now
      } else if (event.phase === Qt.NoScrollPhase && event.angleDelta.y !== 0) {
        root.scrollBy(-event.angleDelta.y)
      }
      if (event.phase === Qt.ScrollEnd && gesture) {
        gesture = false
        if (now - lastT <= 200) {
          var sd = 0, st = 0
          for (var i = 0; i < samples.length; i++) { sd += samples[i].d; st += samples[i].dt }
          if (st > 0) fling.begin(sd / (st / 1000))
        }
        samples = []
      }
    }
  }

  // Chromium's touchpad fling curve: the speed decays as
  // dv/dt = -gamma * (v + beta), so a fast flick slows hard at first and
  // then eases out, stopping on its own. Chromium's constants.
  FrameAnimation {
    id: fling
    property real v: 0      // contentY change per second
    readonly property real beta: 172
    readonly property real gamma: 3.7
    function begin(velocity) {
      if (Reading.reducedMotion || Math.abs(velocity) < 50) return
      v = Math.max(-20946, Math.min(20946, velocity))
      start()
    }
    onTriggered: {
      var speed = (Math.abs(v) + beta) * Math.exp(-gamma * frameTime) - beta
      if (speed <= 0) { stop(); return }
      v = v < 0 ? -speed : speed
      var y = root.clampY(root.contentY + v * frameTime)
      if (y === root.contentY) { stop(); return }
      root.contentY = y
    }
  }

  // ---- live reload: keep the reader on the same block (or the nearest one
  // by source line) at the same offset.
  property var anchorLine: null

  // The block is recognised by its source text (`signature`, supplied by
  // the window), so an edit above it does not move the reader.
  property var signature: null

  function captureAnchor() {
    if (count === 0 || contentY <= originY + 1) { anchorLine = { top: true }; return }
    var i = topIndex
    var item = itemAtIndex(i)
    var b = blocks[i]
    anchorLine = { index: i, line: b ? b.srcStart : 0, sig: b && signature ? signature(b) : "",
                   offset: item ? contentY - item.y : 0 }
  }

  function restoreAnchor() {
    var a = anchorLine
    anchorLine = null
    if (!a) return
    scrollAnim.stop()
    if (a.top) { positionViewAtBeginning(); return }
    var best = -1, bestD = Infinity
    // Same text, nearest to where it was…
    if (a.sig && signature) {
      for (var i = 0; i < blocks.length; i++) {
        if (signature(blocks[i]) !== a.sig) continue
        var d = Math.abs(i - a.index)
        if (d < bestD) { bestD = d; best = i }
      }
    }
    // …or else the nearest block by source line.
    if (best < 0) {
      for (var j = 0; j < blocks.length; j++) {
        var dl = Math.abs(blocks[j].srcStart - a.line)
        if (dl < bestD) { bestD = dl; best = j }
      }
    }
    if (best < 0) return
    positionViewAtIndex(best, ListView.Beginning)
    var item = itemAtIndex(best)
    if (item) contentY = clampY(item.y + Math.min(a.offset, item.height))
  }

  // ---- fade in on open
  opacity: 0
  NumberAnimation on opacity { id: fadeIn; running: false; from: 0; to: 1; duration: Reading.motion(150); easing.type: Easing.OutQuad }
  function appear() {
    if (Reading.reducedMotion) opacity = 1
    else fadeIn.restart()
  }

  delegate: Item {
    id: row
    required property var modelData
    required property int index
    width: root.width
    height: block.height + gap
    readonly property real gap: Reading.gapBefore(index > 0 ? root.blocks[index - 1] : null, modelData)
    // Change marks (MarkdownView.changes). A reworded list marks its items
    // instead; a list added or removed whole is marked once, here.
    readonly property string change: !modelData.change || modelData.change === "same" ? ""
                                     : modelData.type === "list" && modelData.change === "reworded" ? "" : modelData.change
    // A block added or removed whole sits on a wash (green or red);
    // consecutive blocks of one kind share it.
    readonly property string wash: modelData.change === "added" || modelData.change === "removed" ? modelData.change : ""
    readonly property bool prevWash: wash !== "" && index > 0 && root.blocks[index - 1].change === wash
    readonly property bool nextWash: wash !== "" && index + 1 < root.blocks.length && root.blocks[index + 1].change === wash
    // A neighbour washed the other colour: the two share the gap with a seam.
    readonly property bool prevOther: wash !== "" && !prevWash && index > 0 && (root.blocks[index - 1].change === "added" || root.blocks[index - 1].change === "removed")
    readonly property bool nextOther: wash !== "" && !nextWash && index + 1 < root.blocks.length && (root.blocks[index + 1].change === "added" || root.blocks[index + 1].change === "removed")
    readonly property real nextGap: index + 1 < root.blocks.length ? Reading.gapBefore(modelData, root.blocks[index + 1]) : 0
    // Centre of the block's first line box, or of a body line when the
    // block does not say.
    readonly property real firstLineMid: block.item && block.item.lineHeightPx
      ? (block.item.firstLineY || 0) + block.item.lineHeightPx / 2
      : Math.round(Reading.body * Reading.lineHeight / 2)

    Rectangle {
      visible: row.wash !== ""
      x: root.gutter - Reading.washPad
      y: row.prevWash ? 0 : row.prevOther ? Math.round(row.gap / 2) + 1 : row.gap - Style.space(8)
      width: root.column + Reading.washPad + Reading.washPadRight
      height: (row.nextWash ? row.height : row.nextOther ? row.height + Math.round(row.nextGap / 2) - 1 : row.gap + block.height + Style.space(8)) - y
      radius: Math.max(6, Style.cornerRadius)
      topLeftRadius: row.prevWash ? 0 : radius
      topRightRadius: row.prevWash ? 0 : radius
      bottomLeftRadius: row.nextWash ? 0 : radius
      bottomRightRadius: row.nextWash ? 0 : radius
      color: row.wash === "added" ? Theme.flat(Theme.green, Theme.light ? 0.1 : 0.15) : Theme.flat(Theme.red, Theme.light ? 0.08 : 0.12)
    }
    ChangeTag {
      change: row.change
      room: root.gutter - Math.round(Reading.body * 1.9) - Style.space(6)
      // A dot stays inside a margin too narrow for the usual inset.
      x: Math.max(dot ? Math.round((root.gutter - width) / 2) : 0, root.gutter - width - Math.round(Reading.body * 1.9))
      y: Math.round(row.gap + row.firstLineMid - height / 2)
    }

    HoverHandler {
      onHoveredChanged: {
        if (hovered) root.hoveredIndex = row.index
        else if (root.hoveredIndex === row.index) root.hoveredIndex = -1
      }
    }
    // Right-click anywhere on a block copies its Markdown source.
    TapHandler {
      acceptedButtons: Qt.RightButton
      onTapped: if (root.ctx) root.ctx.copyBlock(row.index)
    }

    Block {
      id: block
      x: root.gutter
      y: row.gap
      width: root.column
      block: row.modelData
      ctx: root.ctx
      look: row.wash === "removed" ? ({ removed: true }) : ({})
    }
  }
}
