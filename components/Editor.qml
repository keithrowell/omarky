import QtQuick
import qs.Commons
import qs.services
import "../lib/editing.js" as E

// The writing surface: one plain-text TextEdit on a centred column, painted
// live by MarkdownHighlighter (native/, the Omarky.Native module) when an
// app has built it, plain otherwise. The text is always the file's Markdown,
// exactly; nothing here rewrites it except the keys below. The host binds
// the five settings and decides what each `command` does.
Item {
  id: root

  property alias text: edit.text
  readonly property alias textEdit: edit
  // The native highlighter, or null when the module is not on QML_IMPORT_PATH.
  property var highlighter: null
  readonly property bool highlighted: highlighter !== null
  property bool focusMode: false
  property bool typewriter: false
  property bool spellCheck: true
  property string family: "iA Writer Quattro S"
  property real zoom: 1.0
  readonly property real size: Math.round(Style.font.body * 1.2 * zoom)
  // About 66 characters of the editor's font, the measure Byword used.
  readonly property real measure: Math.min(width - gutter * 2, Math.round(metrics.averageCharacterWidth * 66))
  // Heading marks, list markers and quote marks hang in this gutter.
  readonly property real gutter: Math.round(size * 3.2)
  // A page's padding by default (half a window below, for typewriter
  // scrolling); a host showing one block in a card sets smaller ones.
  property real topPad: typewriter ? height / 2 : Math.max(Style.space(56), height * 0.12)
  property real bottomPad: height / 2
  // The text's height with the padding: what a card sizes itself to.
  readonly property real contentHeight: flick.contentHeight
  readonly property bool typing: typingTimer.running
  readonly property real progress: flick.contentHeight > flick.height ? flick.contentY / (flick.contentHeight - flick.height) : 0

  // Keys the window owns. The editor has focus nearly always, so it passes
  // them up rather than the window listening for them.
  signal command(string name)
  signal contextMenu(real x, real y, var items)

  function forceFocus() { edit.forceActiveFocus() }

  // Replace [start, end) and place the cursor or a selection.
  function apply(r) {
    if (!r) return false
    if (r.end > r.start) edit.remove(r.start, r.end)
    if (r.insert) edit.insert(r.start, r.insert)
    if (r.selStart !== undefined) edit.select(r.selStart, r.selEnd)
    else edit.cursorPosition = r.cursor
    return true
  }

  function selectRange(start, end) {
    edit.select(start, end)
    follow(true)
  }

  // Keep the cursor in view; in typewriter mode keep it on the middle line.
  function follow(force) {
    var r = edit.cursorRectangle
    var cy = edit.y + r.y
    if (root.typewriter) {
      glide(cy + r.height / 2 - flick.height / 2, force ? 220 : 120)
      return
    }
    var margin = Math.min(flick.height / 4, r.height * 3)
    if (cy - margin < flick.contentY) glide(cy - margin, force ? 220 : 0)
    else if (cy + r.height + margin > flick.contentY + flick.height) glide(cy + r.height + margin - flick.height, force ? 220 : 0)
  }

  function clampY(y) { return Math.max(0, Math.min(y, flick.contentHeight - flick.height)) }

  function glide(y, ms) {
    y = clampY(y)
    fling.stop()
    if (Reading.reducedMotion || ms === 0) { scrollAnim.stop(); flick.contentY = y; return }
    scrollAnim.duration = ms
    scrollAnim.to = y
    scrollAnim.restart()
  }

  function scrollBy(d) { glide((scrollAnim.running ? scrollAnim.to : flick.contentY) + d, 160) }

  // Where the cursor's line sits in the source, for matching the preview.
  function cursorLine() { return E.lineNumber(edit.text, edit.cursorPosition) }

  FontMetrics { id: metrics; font.family: root.family; font.styleName: "Regular"; font.pixelSize: root.size }

  Timer { id: typingTimer; interval: 1400 }

  Flickable {
    id: flick
    anchors.fill: parent
    contentWidth: width
    contentHeight: root.topPad + edit.height + root.bottomPad
    interactive: false
    clip: true

    NumberAnimation { id: scrollAnim; target: flick; property: "contentY"; easing.type: Easing.OutCubic }

    // Clicks in the margins still land in the text.
    MouseArea {
      width: flick.width
      height: flick.contentHeight
      cursorShape: Qt.IBeamCursor
      onPressed: mouse => {
        var p = mapToItem(edit, mouse.x, mouse.y)
        edit.cursorPosition = edit.positionAt(Math.max(0, Math.min(p.x, edit.width)), Math.max(0, Math.min(p.y, edit.height - 1)))
        edit.forceActiveFocus()
      }
    }

    TextEdit {
      id: edit
      x: Math.round((flick.width - root.measure) / 2 - root.gutter)
      y: root.topPad
      width: root.measure + root.gutter * 2
      textFormat: TextEdit.PlainText
      wrapMode: TextEdit.Wrap
      font.family: root.family
      font.styleName: "Regular"
      font.pixelSize: root.size
      color: Theme.text
      selectionColor: Theme.selection
      selectedTextColor: Theme.strong
      selectByMouse: true
      persistentSelection: false
      focus: true
      tabStopDistance: metrics.averageCharacterWidth * 4
      cursorDelegate: Rectangle {
        id: caret
        width: Math.max(2, Math.round(root.size / 9))
        radius: width / 2
        color: Theme.accent
        visible: edit.activeFocus
        SequentialAnimation on opacity {
          running: edit.activeFocus && !root.typing
          loops: Animation.Infinite
          alwaysRunToEnd: false
          PauseAnimation { duration: 520 }
          NumberAnimation { to: 0; duration: Reading.motion(180) }
          PauseAnimation { duration: 340 }
          NumberAnimation { to: 1; duration: Reading.motion(180) }
        }
        Connections { target: root; function onTypingChanged() { if (root.typing) caret.opacity = 1 } }
      }

      onTextChanged: typingTimer.restart()
      onCursorRectangleChanged: if (activeFocus) root.follow(false)

      Keys.onPressed: event => root.handleKey(event)

      // Right-click: spelling suggestions for a misspelt word, then the
      // usual edit actions.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.IBeamCursor
        onPressed: mouse => {
          var pos = edit.positionAt(mouse.x, mouse.y)
          var items = []
          var w = E.wordAt(edit.text, pos)
          var hl = root.highlighter
          if (w && hl && root.spellCheck && !hl.isCorrect(w.word)) {
            var s = hl.suggestions(w.word)
            for (var i = 0; i < s.length; i++)
              items.push({ label: s[i], strong: true, run: (function(word, a, b) { return function() { root.apply({ start: a, end: b, insert: word, cursor: a + word.length }) } })(s[i], w.start, w.end) })
            if (s.length === 0) items.push({ label: "No suggestions", disabled: true })
            items.push({ label: "Add “" + w.word + "” to dictionary", run: (function(word) { return function() { hl.addToDictionary(word) } })(w.word) })
            items.push({ separator: true })
          }
          if (edit.selectionStart === edit.selectionEnd) edit.cursorPosition = pos
          items.push({ label: "Cut", keys: "Ctrl+X", disabled: edit.selectedText === "", run: function() { edit.cut() } })
          items.push({ label: "Copy", keys: "Ctrl+C", disabled: edit.selectedText === "", run: function() { edit.copy() } })
          items.push({ label: "Paste", keys: "Ctrl+V", run: function() { edit.paste() } })
          var p = mapToItem(root, mouse.x, mouse.y)
          root.contextMenu(p.x, p.y, items)
        }
      }
    }
  }

  // Colours and fonts for the highlighter, all at once so a theme switch
  // repaints once.
  readonly property var look: ({
      text: Theme.hex(Theme.text),
      strong: Theme.hex(Theme.strong),
      dim: Theme.hex(Theme.dim),
      faint: Theme.hex(Theme.faint),
      ghost: Theme.hex(Theme.mix(Theme.fg, Theme.bg, 0.72)),
      accent: Theme.hex(Theme.accent),
      link: Theme.hex(Theme.link),
      mark: Theme.hex(Theme.mix(Theme.accent, Theme.bg, 0.15)),
      code: Theme.hex(Theme.mix(Theme.text, Theme.accent, 0.12)),
      codeBg: Theme.hex(Theme.flat(Theme.fg, Theme.light ? 0.07 : 0.085)),
      error: Theme.hex(Theme.red),
      prose: root.family,
      mono: Reading.mono,
      size: root.size,
      lineHeight: 155,
      gutter: root.gutter
    })

  // The module is optional, and a failed import would fail this whole file,
  // so NativeHighlighter.qml imports it and is created here only if it loads.
  Component.onCompleted: {
    var c = Qt.createComponent(Qt.resolvedUrl("NativeHighlighter.qml"))
    if (c.status === Component.Ready) {
      root.highlighter = c.createObject(root, { edit: edit, editor: root })
    } else {
      console.info("Omarky: the editor runs without the native highlighter (" + c.errorString().trim().split("\n")[0] + ")")
    }
  }

  // ---- touchpad and wheel: OmaRead's Chromium-matched scrolling (its
  // decision 0011), on the editor's Flickable.
  WheelHandler {
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    property bool gesture: false
    property real lastT: 0
    property var samples: []
    onWheel: event => {
      var now = Date.now()
      var dy = event.pixelDelta.y
      if (dy !== 0) {
        if (!gesture) { gesture = true; fling.stop(); scrollAnim.stop(); samples = []; lastT = now }
        var d = -dy * 12
        flick.contentY = root.clampY(flick.contentY + d)
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

  FrameAnimation {
    id: fling
    property real v: 0
    function begin(velocity) {
      if (Reading.reducedMotion || Math.abs(velocity) < 50) return
      v = Math.max(-20946, Math.min(20946, velocity))
      start()
    }
    onTriggered: {
      var speed = (Math.abs(v) + 172) * Math.exp(-3.7 * frameTime) - 172
      if (speed <= 0) { stop(); return }
      v = v < 0 ? -speed : speed
      var y = root.clampY(flick.contentY + v * frameTime)
      if (y === flick.contentY) { stop(); return }
      flick.contentY = y
    }
  }

  // A hairline scroll thumb that shows while scrolling.
  Rectangle {
    anchors.right: parent.right
    anchors.rightMargin: Style.space(4)
    width: Style.space(3)
    radius: width / 2
    color: Theme.faint
    visible: flick.contentHeight > flick.height * 1.05
    height: Math.max(Style.space(24), flick.height * flick.height / flick.contentHeight)
    y: (flick.height - height) * root.progress
    opacity: scrollAnim.running || fling.running || flickShow.running ? 0.5 : 0
    Behavior on opacity { NumberAnimation { duration: Reading.motion(300) } }
  }
  Timer { id: flickShow; interval: 700 }
  Connections { target: flick; function onContentYChanged() { flickShow.restart() } }

  function handleKey(event) {
    var ctrl = event.modifiers & Qt.ControlModifier
    var shift = event.modifiers & Qt.ShiftModifier
    var alt = event.modifiers & Qt.AltModifier
    var k = event.key
    var t = edit.text
    var a = edit.selectionStart, b = edit.selectionEnd

    if ((k === Qt.Key_Return || k === Qt.Key_Enter) && !ctrl && !alt && !shift && a === b) {
      if (root.apply(E.enter(t, edit.cursorPosition))) event.accepted = true
      return
    }
    // Ctrl+Enter: "done" for a host that edits one piece of text (a sheet).
    if ((k === Qt.Key_Return || k === Qt.Key_Enter) && ctrl) { root.command("submit"); event.accepted = true; return }
    if (k === Qt.Key_Tab && !ctrl && a === b) {
      if (!root.apply(E.indent(t, edit.cursorPosition, false))) edit.insert(edit.cursorPosition, "    ")
      event.accepted = true
      return
    }
    if (k === Qt.Key_Backtab && !ctrl) {
      root.apply(E.indent(t, edit.cursorPosition, true))
      event.accepted = true
      return
    }
    if (ctrl && !alt) {
      var wrapKey = { [Qt.Key_B]: "**", [Qt.Key_I]: "*", [Qt.Key_E]: "`" }
      if (!shift && wrapKey[k]) { root.apply(E.wrap(t, a, b, wrapKey[k])); event.accepted = true; return }
      if (shift && k === Qt.Key_X) { root.apply(E.wrap(t, a, b, "~~")); event.accepted = true; return }
      if (!shift && k === Qt.Key_K) { root.apply(E.link(t, a, b)); event.accepted = true; return }
      if (!shift && k >= Qt.Key_0 && k <= Qt.Key_6) { root.apply(E.heading(t, edit.cursorPosition, k - Qt.Key_0)); event.accepted = true; return }
      var commands = shift
        ? { [Qt.Key_F]: "focus", [Qt.Key_T]: "typewriter", [Qt.Key_L]: "spell", [Qt.Key_S]: "saveAs", [Qt.Key_M]: "font", [Qt.Key_P]: "preview" }
        : { [Qt.Key_S]: "save", [Qt.Key_N]: "new", [Qt.Key_O]: "open", [Qt.Key_W]: "close", [Qt.Key_P]: "preview",
            [Qt.Key_F]: "find", [Qt.Key_R]: "recent", [Qt.Key_Equal]: "zoomIn", [Qt.Key_Plus]: "zoomIn", [Qt.Key_Minus]: "zoomOut",
            [Qt.Key_Slash]: "help", [Qt.Key_Question]: "help", [Qt.Key_G]: "findNext" }
      if (commands[k]) { root.command(commands[k]); event.accepted = true; return }
    }
    if (k === Qt.Key_Escape) { root.command("escape"); event.accepted = true; return }
    if (k === Qt.Key_F3) { root.command(shift ? "findPrev" : "findNext"); event.accepted = true; return }
  }
}
