import QtQuick
import QtQuick.Dialogs
import Quickshell
import qs.Commons
import qs.services

// One window per open file: the header, the outline, the reading column,
// find, and every key in §5 of the spec.
FloatingWindow {
  id: win
  property string path: ""
  property string initialAnchor: ""
  readonly property string fileName: path ? path.split("/").pop() : ""
  readonly property string dir: path ? path.slice(0, path.lastIndexOf("/")) : ""
  readonly property string folderLabel: {
    var home = Quickshell.env("HOME")
    return dir.indexOf(home) === 0 ? "~" + dir.slice(home.length) : dir
  }
  readonly property Item grabRoot: page
  // The renderer's parts, under the names the rest of this file uses.
  readonly property var doc: md.doc
  readonly property var view: md.view
  readonly property var ctx: md.ctx
  readonly property var finder: md.finder
  // Screenshot-only switches (tools/screenshot): outline, wide, find, help.
  property var shotOptions: ({})

  property bool wide: false
  property bool outlineWanted: width >= Style.space(1180)
  readonly property bool outlineShown: outlineWanted && doc.headings.length > 1 && !!path
  property bool findShown: false
  property bool helpShown: false
  property bool pendingG: false

  // Asks the shell to open another file in a new window, or to close this.
  signal openFile(string path, string anchor)
  signal closeRequested()

  title: fileName ? "OmaRead — " + fileName : "OmaRead"
  implicitWidth: Style.space(1180)
  implicitHeight: Style.space(900)
  color: Theme.bg

  // Scrolls one screen for the screenshot driver; false at the end.
  function shotNextPage() { return view.pageDown() }

  function applyShotOptions() {
    var o = shotOptions || {}
    if (o.outline !== undefined) outlineWanted = !!o.outline
    if (o.wide !== undefined) wide = !!o.wide
    if (o.help) helpShown = true
    if (o.find) { findShown = true; findBar.query = String(o.find) }
    if (o.reloaded) header.pulse()
    if (o.missing) doc.missing = true
    if (o.hover !== undefined) view.hoveredIndex = o.hover
    // Screenshots start with the anchored heading near the top.
    if (o.anchor) Qt.callLater(function() {
      var i = doc.anchorMap[o.anchor]
      if (i === undefined) return
      view.positionViewAtIndex(i, ListView.Beginning)
      var item = view.itemAtIndex(i)
      if (item) view.contentY = view.clampY(item.y + item.gap - Style.space(26))
    })
  }

  // ---- dev hooks for IPC checks (shell.qml)
  function debugState() {
    return {
      title: title, width: width, height: height, implicitW: implicitWidth, path: path, loaded: doc.loaded, missing: doc.missing, blocks: doc.blocks.length,
      parseMs: doc.parseMs, reloads: doc.reloads, topLine: doc.blocks[view.topIndex] ? doc.blocks[view.topIndex].srcStart : -1, contentY: Math.round(view.contentY), topIndex: view.topIndex,
      progress: Math.round(view.progress * 1000) / 1000, outline: outlineShown, wide: wide,
      theme: Theme.name, bg: Theme.hex(Theme.bg), kshTheme: Highlight.themeName, column: Math.round(view.column), zoom: Prefs.zoom, body: Reading.body, help: helpShown,
      find: { shown: findShown, query: finder.query, count: finder.matches.length, current: finder.current },
      clipboard: Quickshell.clipboardText.slice(0, 200), selection: ctx.selectionOwner ? ctx.selectionOwner.selectedText : ""
    }
  }

  function debugLink(href) { ctx.openLink(href) }

  // Scroll the whole document in 120 px steps, building delegates
  // synchronously; reports the slowest step (the delegate-creation cost a
  // real frame would pay).
  function debugBench() {
    view.positionViewAtBeginning()
    var worst = 0, total = 0, steps = 0, t0 = Date.now(), slow = []
    while (!view.atYEnd && steps < 5000) {
      var s = Date.now()
      view.contentY += 120
      view.forceLayout()
      var d = Date.now() - s
      if (d > 16) {
        var bottom = view.topIndex
        slow.push(d + "ms@" + bottom + ":" + (doc.blocks[bottom] ? doc.blocks[bottom].type + "/" + (doc.blocks[bottom].lang || doc.blocks[bottom].lineCount || "") : "?"))
      }
      worst = Math.max(worst, d); total += d; steps++
    }
    return { steps: steps, worstMs: worst, meanMs: Math.round(total / Math.max(1, steps) * 10) / 10,
             over16: slow.length, slow: slow.slice(0, 12), totalMs: Date.now() - t0 }
  }
  function debugHover(index) { view.hoveredIndex = index }

  // "j", "G", "ctrl+f", "shift+space", "escape", "enter", "type:hello"
  function sendKey(spec) {
    if (spec.indexOf("type:") === 0) { findBar.query = spec.slice(5); return }
    var parts = spec.split("+"), name = parts.pop(), mods = 0
    parts.forEach(function(m) {
      if (m === "ctrl") mods |= Qt.ControlModifier
      if (m === "shift") mods |= Qt.ShiftModifier
    })
    var named = { space: Qt.Key_Space, escape: Qt.Key_Escape, enter: Qt.Key_Return, down: Qt.Key_Down, up: Qt.Key_Up,
                  pagedown: Qt.Key_PageDown, pageup: Qt.Key_PageUp, home: Qt.Key_Home, end: Qt.Key_End,
                  backslash: Qt.Key_Backslash, plus: Qt.Key_Plus, minus: Qt.Key_Minus }
    var key = named[name] || (name.length === 1 ? name.toUpperCase().charCodeAt(0) : 0)
    var text = name.length === 1 ? name : name === "space" ? " " : ""
    if (name.length === 1 && name >= "0" && name <= "9") key = Qt.Key_0 + Number(name)
    var ev = { key: key, text: mods & Qt.ControlModifier ? "" : text, modifiers: mods, accepted: false }
    if (findShown && (name === "enter" || name === "escape")) {
      if (name === "escape") closeFind()
      else if (mods & Qt.ShiftModifier) finder.go(finder.current - 1)
      else finder.go(finder.current + 1)
      return
    }
    handleKey(ev)
  }

  function loadPath(p) {
    path = p
    if (p) Prefs.addRecent(p)
  }

  // Picks up the window's anchor once the file is in, and flashes the
  // header on each live reload.
  Connections {
    target: win.doc
    function onLoadedChanged() {
      if (win.doc.loaded && win.initialAnchor) Qt.callLater(function() { win.view.scrollToAnchor(win.initialAnchor) })
    }
    function onReloaded() { header.pulse() }
  }

  // ---- keys
  function handleKey(event) {
    var ctrl = event.modifiers & Qt.ControlModifier
    var shift = event.modifiers & Qt.ShiftModifier
    var k = event.key, t = event.text

    if (helpShown) {
      if (k === Qt.Key_Escape || t === "?" || t === "q") helpShown = false
      event.accepted = true
      return
    }
    if (ctrl && shift && k === Qt.Key_C) { if (view.hoveredIndex >= 0) ctx.copyBlock(view.hoveredIndex); event.accepted = true; return }
    if (ctrl && shift && k === Qt.Key_A) { ctx.copyText(doc.source, "Copied the whole file"); event.accepted = true; return }
    if (ctrl) {
      if (k === Qt.Key_C) {
        if (ctx.selectionOwner && ctx.selectionOwner.selectedText) ctx.copyText(ctx.selectionOwner.selectedText)
      } else if (k === Qt.Key_F) {
        findShown = true
        findBar.focusField()
      } else if (k === Qt.Key_O) {
        fileDialog.open()
      } else if (k === Qt.Key_R) {
        doc.reload()
      } else if (k === Qt.Key_W) {
        win.closeRequested()
      } else if (k === Qt.Key_Backslash) {
        outlineWanted = !outlineWanted
      } else if (k === Qt.Key_Plus || k === Qt.Key_Equal) {
        Prefs.setZoom(Prefs.zoom + 0.1)
      } else if (k === Qt.Key_Minus) {
        Prefs.setZoom(Prefs.zoom - 0.1)
      } else if (k === Qt.Key_0) {
        Prefs.setZoom(1)
      } else return
      event.accepted = true
      return
    }
    if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) return

    if (pendingG) {
      pendingG = false
      chordTimer.stop()
      if (t === "g") { view.toTop(); event.accepted = true; return }
    }
    if (t === "g") { pendingG = true; chordTimer.restart(); event.accepted = true; return }
    if (t === "G") view.toBottom()
    else if (t === "j" || k === Qt.Key_Down) view.scrollBy(view.lineStep())
    else if (t === "k" || k === Qt.Key_Up) view.scrollBy(-view.lineStep())
    else if (k === Qt.Key_Space || k === Qt.Key_PageDown) view.scrollBy(shift && k === Qt.Key_Space ? -view.pageStep() : view.pageStep())
    else if (k === Qt.Key_PageUp) view.scrollBy(-view.pageStep())
    else if (k === Qt.Key_Home) view.toTop()
    else if (k === Qt.Key_End) view.toBottom()
    else if (t === "?") helpShown = true
    else if (t === "q") win.closeRequested()
    else if (t === "w" || t === "W") wide = !wide
    else if (t === "n" && finder.query) finder.go(finder.current + 1)
    else if (t === "N" && finder.query) finder.go(finder.current - 1)
    else if (t === "/") { findShown = true; findBar.focusField() }
    else if (k === Qt.Key_Escape) {
      if (findShown) closeFind()
      else if (ctx.selectionOwner) { ctx.selectionOwner.deselect(); ctx.selectionOwner = null }
    } else return
    event.accepted = true
  }

  function closeFind() {
    findShown = false
    finder.query = ""
    finder.matches = []
    finder.current = -1
    keySink.forceActiveFocus()
  }

  Timer { id: chordTimer; interval: 900; onTriggered: win.pendingG = false }

  FileDialog {
    id: fileDialog
    title: "Open a Markdown file"
    nameFilters: ["Markdown (*.md *.markdown *.mdown *.mkd *.mdx)", "All files (*)"]
    currentFolder: win.dir ? "file://" + win.dir : "file://" + Quickshell.env("HOME")
    onAccepted: {
      var p = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
      if (!win.path) win.loadPath(p)
      else win.openFile(p, "")
    }
  }

  FocusScope {
    id: page
    anchors.fill: parent
    focus: true
    Keys.onPressed: event => win.handleKey(event)

    Item { id: keySink; focus: true }

    // Opaque base so grabs render exactly as on screen.
    Rectangle { anchors.fill: parent; color: Theme.bg }

    Header {
      id: header
      width: parent.width
      fileName: win.fileName
      folder: win.folderLabel
      outlineShown: win.outlineShown
      outlineAvailable: doc.headings.length > 1
      wide: win.wide
      findShown: win.findShown
      hasDocument: !!win.path && doc.loaded
      onToggleOutline: win.outlineWanted = !win.outlineWanted
      onToggleWide: win.wide = !win.wide
      onToggleFind: { if (win.findShown) win.closeFind(); else { win.findShown = true; findBar.focusField() } }
      onCopyAll: ctx.copyText(doc.source, "Copied the whole file")
      onShowHelp: win.helpShown = true
    }

    // Reading progress along the top edge.
    Rectangle {
      z: 5
      height: 2
      width: Math.round(parent.width * view.progress)
      color: Theme.accent
      visible: !!win.path
      Behavior on width { NumberAnimation { duration: Reading.motion(90) } }
    }

    // Floats over the page's top margin rather than pushing the text down.
    Banner {
      id: banner
      z: 3
      anchors.top: header.bottom
      width: parent.width
      visible: doc.missing
      text: win.fileName + " was deleted or moved. Showing the last version; it reappears if the file comes back."
    }

    Item {
      id: body
      anchors.top: header.bottom
      anchors.bottom: parent.bottom
      width: parent.width

      Outline {
        id: outline
        width: Style.space(264)
        height: parent.height
        x: win.outlineShown ? 0 : -width
        visible: x > -width
        headings: doc.headings
        current: {
          var top = view.topIndex, best = -1
          for (var i = 0; i < doc.headings.length; i++) {
            if (doc.headings[i].index <= top) best = i
            else break
          }
          return best
        }
        onJump: index => view.scrollToIndex(index, true)
        Behavior on x { NumberAnimation { duration: Reading.motion(160); easing.type: Easing.OutCubic } }
      }

      MarkdownView {
        id: md
        x: outline.x + outline.width
        width: parent.width - x
        height: parent.height
        path: win.path
        documentName: win.fileName
        wide: win.wide
        onNotice: t => toast.show(t)
        onOpenFile: (p, a) => win.openFile(p, a)
      }

      EmptyState {
        anchors.fill: parent
        visible: !win.path || (doc.failed && !doc.loaded)
        recent: Prefs.recent
        problem: win.path && doc.failed ? "Cannot open " + win.fileName : ""
        onOpenRequested: fileDialog.open()
        onOpenPath: p => { if (!win.path || doc.failed) win.loadPath(p); else win.openFile(p, "") }
      }
    }

    FindBar {
      id: findBar
      z: 4
      visible: win.findShown
      anchors.right: parent.right
      anchors.rightMargin: Style.space(16)
      y: header.height + (banner.visible ? banner.height : 0) + Style.space(10)
      count: finder.matches.length
      current: finder.current
      onQueryChanged: findDebounce.restart()
      onNext: finder.go(finder.current + 1)
      onPrevious: finder.go(finder.current - 1)
      onCloseRequested: win.closeFind()
    }
    Timer {
      id: findDebounce
      interval: doc.blocks.length > 400 ? 120 : 40
      onTriggered: finder.search(findBar.query)
    }

    ShortcutSheet {
      anchors.fill: parent
      z: 6
      visible: win.helpShown
      onCloseRequested: win.helpShown = false
    }

    Toast { id: toast; z: 7 }

    // Drop a Markdown file anywhere on the window.
    DropArea {
      anchors.fill: parent
      z: 8
      keys: ["text/uri-list"]
      onEntered: drag => drag.accept(Qt.CopyAction)
      onDropped: drop => {
        var urls = drop.urls || []
        for (var i = 0; i < urls.length; i++) {
          var p = decodeURIComponent(String(urls[i]).replace(/^file:\/\//, ""))
          if (i === 0 && (!win.path || doc.failed)) win.loadPath(p)
          else win.openFile(p, "")
        }
        drop.accept(Qt.CopyAction)
      }
      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(10)
        visible: parent.containsDrag
        color: Util.alpha(Theme.accent, 0.06)
        radius: Math.max(6, Style.cornerRadius)
        border.width: 2
        border.color: Util.alpha(Theme.accent, 0.5)
      }
    }
  }

  Component.onCompleted: {
    if (path) Prefs.addRecent(path)
    Qt.callLater(applyShotOptions)
  }
}
