import QtQuick
import QtQuick.Dialogs
import Quickshell
import qs.Commons
import qs.services
import "../lib/blocks.js" as Blocks

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
  }

  // ---- dev hooks for IPC checks (shell.qml)
  function debugState() {
    return {
      title: title, width: width, height: height, implicitW: implicitWidth, path: path, loaded: doc.loaded, missing: doc.missing, blocks: doc.blocks.length,
      parseMs: doc.parseMs, reloads: doc.reloads, topLine: doc.blocks[view.topIndex] ? doc.blocks[view.topIndex].srcStart : -1, contentY: Math.round(view.contentY), topIndex: view.topIndex,
      progress: Math.round(view.progress * 1000) / 1000, outline: outlineShown, wide: wide,
      column: Math.round(view.column), zoom: Prefs.zoom, body: Reading.body, help: helpShown,
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

  // ---- what blocks call back into: links, copying, resolving paths, find
  QtObject {
    id: ctx

    property Item selectionOwner: null
    readonly property QtObject finder: finder

    function resolveUrl(src) {
      var s = String(src || "")
      if (/^(https?|file|data|qrc):/i.test(s)) return s
      if (s.charAt(0) === "~") s = Quickshell.env("HOME") + s.slice(1)
      if (s.charAt(0) !== "/") s = win.dir + "/" + s
      return "file://" + encodeURI(decodeURI(s))
    }

    function copyText(text, note) {
      Quickshell.clipboardText = String(text)
      toast.show(note || "Copied")
    }

    function copyAnchor(slug) {
      copyText(win.fileName + "#" + slug, "Copied " + win.fileName + "#" + slug)
    }

    function copyBlock(index) {
      var b = doc.blocks[index]
      if (!b) return
      copyText(doc.sourceLines(b.srcStart, b.srcEnd), "Copied the block's Markdown")
    }

    // Only one text item keeps a selection at a time; Ctrl+C copies it.
    function claimSelection(item) {
      if (selectionOwner && selectionOwner !== item && selectionOwner.deselect) selectionOwner.deselect()
      selectionOwner = item
    }

    // http(s) and mailto open with xdg-open; #anchors scroll; relative .md
    // files open in a new OmaRead window; other local files via xdg-open.
    function openLink(href) {
      var h = String(href || "")
      if (!h) return
      if (h.charAt(0) === "#") { view.scrollToAnchor(decodeURIComponent(h.slice(1))); return }
      if (/^(https?|mailto|ftp):/i.test(h)) { Quickshell.execDetached(["xdg-open", h]); return }
      var hash = h.indexOf("#")
      var target = hash >= 0 ? h.slice(0, hash) : h
      var frag = hash >= 0 ? decodeURIComponent(h.slice(hash + 1)) : ""
      target = decodeURI(target.replace(/^file:\/\//, ""))
      if (target === "" || target === win.path) { if (frag) view.scrollToAnchor(frag); return }
      if (target.charAt(0) === "~") target = Quickshell.env("HOME") + target.slice(1)
      if (target.charAt(0) !== "/") target = win.dir + "/" + target
      if (/\.(md|markdown|mdown|mkd|mdx)$/i.test(target)) win.openFile(target, frag)
      else Quickshell.execDetached(["xdg-open", target])
    }

    // A text item holding the current match reports where it is.
    function revealMatch(item, localY) { view.reveal(item, localY) }
  }

  // ---- find: every match in document order; the current one by piece id
  QtObject {
    id: finder
    property string query: ""
    property var matches: []
    property int current: -1
    readonly property int currentPid: current >= 0 && current < matches.length ? matches[current].pid : -1
    readonly property int currentK: current >= 0 && current < matches.length ? matches[current].k : -1

    function search(q) {
      query = q
      matches = Blocks.findAll({ pieces: doc.pieces }, q)
      // Start from the first match at or below the top of the page.
      var top = view.topIndex, pick = matches.length ? 0 : -1
      for (var i = 0; i < matches.length; i++) if (matches[i].block >= top) { pick = i; break }
      go(pick)
    }

    function go(i) {
      if (!matches.length) { current = -1; return }
      current = (i + matches.length) % matches.length
      var m = matches[current]
      // Off-screen blocks are brought in first; the text item holding the
      // match then refines the position (ctx.revealMatch).
      var bottom = view.indexAt(view.width / 2, view.contentY + view.height - 1)
      if (!view.itemAtIndex(m.block) || m.block < view.topIndex || (bottom >= 0 && m.block > bottom))
        view.positionViewAtIndex(m.block, ListView.Center)
    }

    function refresh() {
      if (!query) return
      var c = current
      matches = Blocks.findAll({ pieces: doc.pieces }, query)
      current = Math.min(c, matches.length - 1)
    }
  }

  Doc {
    id: doc
    path: win.path
    onAboutToReload: view.captureAnchor()
    onReloaded: {
      view.restoreAnchor()
      header.pulse()
      finder.refresh()
    }
    onLoadedChanged: if (loaded) {
      view.appear()
      if (win.initialAnchor) Qt.callLater(function() { view.scrollToAnchor(win.initialAnchor) })
    }
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

      DocView {
        id: view
        x: outline.x + outline.width
        width: parent.width - x
        height: parent.height
        visible: !!win.path && doc.loaded
        blocks: doc.blocks
        anchorMap: doc.anchorMap
        lineCount: doc.lineCount
        wide: win.wide
        ctx: ctx
        signature: b => b.type + "\n" + doc.sourceLines(b.srcStart, b.srcEnd)
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

    HighlightWarmup {
      langs: {
        var seen = {}, out = []
        function walk(list) {
          for (var i = 0; i < list.length; i++) {
            var b = list[i]
            if (b.type === "code" && b.lang && !seen[b.lang]) { seen[b.lang] = true; out.push(b.lang) }
            if (b.blocks) walk(b.blocks)
            if (b.items) b.items.forEach(function(it) { if (it.blocks) walk(it.blocks) })
          }
        }
        walk(doc.blocks)
        return out
      }
    }

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
