import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services

// One window per open file: the header, the outline, the reading column,
// find, and every key in §5 of the spec. When the file has earlier versions
// in git, the same window compares two of them (changes mode): the pill in
// the header names the two ends, the column shows the newer text with the
// changes marked, and the fold shows only what changed.
FloatingWindow {
  id: win
  property string path: ""
  property string initialAnchor: ""
  // Open comparing straight away: specs for `omaread FILE --resolve`.
  property string fromSpec: ""
  property string toSpec: ""
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
  // Screenshot-only switches (tools/screenshot): outline, wide, find, help,
  // from (a spec), fold, versions.
  property var shotOptions: ({})
  // The screenshot driver waits while a version is being resolved.
  readonly property bool shotBusy: resolver.running || (fromSpec !== "" && !changes.active) || versionsProc.running

  property bool wide: false
  property bool outlineWanted: width >= Style.space(1180)
  readonly property bool outlineShown: outlineWanted && doc.headings.length > 1 && !!path
  property bool findShown: false
  property bool helpShown: false
  property bool pendingG: false

  // ---- versions: what git knows about the file
  property var versions: ({ inRepo: false, dirty: false, history: [], shortcuts: [] })
  readonly property bool hasHistory: versions.history.length > 0
  property bool listShown: false
  // "from": the next pick sets what Now is compared with. "to": the next
  // pick sets the newer end (Compare two past versions…).
  property string picking: "from"
  readonly property bool comparing: changes.active
  property bool shotListAfter: false
  onComparingChanged: if (comparing && shotListAfter) { shotListAfter = false; listShown = true }

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
    if (o.from) fromSpec = String(o.from)
    if (o.fold) changes.foldOn = true
    // The list opens once the comparison is in (a pick closes it).
    if (o.versions) { if (o.from) shotListAfter = true; else listShown = true }
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
      clipboard: Quickshell.clipboardText.slice(0, 200), selection: ctx.selectionOwner ? ctx.selectionOwner.selectedText : "",
      hasHistory: hasHistory, dirty: versions.dirty, versions: versions.history.length, list: listShown, picking: picking,
      comparing: comparing, from: changes.from ? changes.from.label : "", to: changes.to ? changes.to.label : "",
      total: changes.total, fold: changes.foldOn, folds: doc.blocks.filter(function(b) { return b.type === "fold" }).length,
      banner: changes.banner, compareMs: changes.compareMs
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
  // header on each live reload. A reload may be a new check-in too.
  Connections {
    target: win.doc
    function onLoadedChanged() {
      if (!win.doc.loaded) return
      if (win.initialAnchor) Qt.callLater(function() { win.view.scrollToAnchor(win.initialAnchor) })
      if (win.fromSpec) win.startComparison()
    }
    // While comparing, a reload is a fold or a pick as often as a disk
    // change; the disk changes come through Changes instead.
    function onReloaded() { if (!changes.active) header.pulse(); versionsDebounce.restart() }
  }

  // ---- the launcher answers questions about git; the window never runs it
  readonly property string launcher: Quickshell.env("OMAREAD_BIN") || (Quickshell.shellDir + "/bin/omaread")

  Process {
    id: versionsProc
    stdout: StdioCollector {
      onStreamFinished: {
        if (!text.trim()) return
        try { win.versions = JSON.parse(text) } catch (e) { console.warn("OmaRead: bad --versions output: " + e) }
      }
    }
  }
  function refreshVersions() {
    if (!path) return
    versionsProc.command = [launcher, path, "--versions"]
    versionsProc.running = true
  }
  onPathChanged: { changes.clear(); refreshVersions() }
  Timer { id: versionsDebounce; interval: 400; onTriggered: win.refreshVersions() }

  Process {
    id: resolver
    property string side: "from"
    stdout: StdioCollector { onStreamFinished: win.applyResolved(resolver.side, text) }
    stderr: StdioCollector { onStreamFinished: if (text.trim()) toast.show(text.trim()) }
  }

  function resolveSpec(spec, side) {
    if (!path || !spec) return
    resolver.side = side || "from"
    var cmd = [launcher, path, "--resolve", String(spec)]
    // The older end is found among the versions before the newer one.
    if (resolver.side === "from" && changes.to && changes.to.sha) cmd.push("--to", changes.to.sha)
    resolver.command = cmd
    resolver.running = true
  }

  function applyResolved(side, json) {
    if (!json || !json.trim()) { if (fromSpec && !changes.active) { fromSpec = ""; toSpec = "" }; return }
    var v
    try { v = JSON.parse(json) } catch (e) { toast.show("Could not read that version"); return }
    var wasOpen = listShown
    if (!changes.active) changes.nowText = doc.source
    if (side === "from") {
      changes.from = v
      if (!changes.to) changes.to = nowSide()
    } else {
      changes.to = v
      // Opening with both ends given: the older end follows the newer.
      if (fromSpec && !changes.from) { resolveSpec(fromSpec, "from"); return }
    }
    if (v.label === "Now") changes.nowText = v.text || ""
    if (picking === "to") { picking = "from"; listShown = true }
    else if (wasOpen) listShown = false
  }

  function nowSide() { return { label: "Now", who: "Now" } }

  // Opening straight into a comparison: the newer end first when there is
  // one (applyResolved then asks for the older), else the older against Now.
  function startComparison() {
    if (!fromSpec || !doc.loaded || changes.active || resolver.running) return
    if (toSpec && toSpec.toLowerCase() !== "now") resolveSpec(toSpec, "to")
    else resolveSpec(fromSpec, "from")
  }
  Component.onCompleted: {
    if (path) Prefs.addRecent(path)
    refreshVersions()
    Qt.callLater(applyShotOptions)
  }
  onFromSpecChanged: startComparison()

  function pickVersion(spec) { resolveSpec(spec, picking === "to" ? "to" : "from") }

  function stopComparing() {
    changes.clear()
    fromSpec = ""
    toSpec = ""
    listShown = false
    picking = "from"
  }

  function toggleList() {
    listShown = !listShown
    if (!listShown) picking = "from"
  }

  // ---- moving between changes
  function step(dir) {
    var idx = changes.changedIndices(doc.blocks)
    if (!idx.length) return
    var top = view.topIndex, pick = -1
    if (dir > 0) { for (var i = 0; i < idx.length; i++) if (idx[i] > top) { pick = idx[i]; break } }
    else { for (var k = idx.length - 1; k >= 0; k--) if (idx[k] < top) { pick = idx[k]; break } }
    if (pick < 0) pick = dir > 0 ? idx[0] : idx[idx.length - 1]
    view.scrollToIndex(pick, true)
    flash.target = pick
    flashTimer.restart()
  }

  Changes {
    id: changes
    path: win.path
    onDiskChanged: { header.pulse(); versionsDebounce.restart() }
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
    if (listShown && k === Qt.Key_Escape) { listShown = false; picking = "from"; event.accepted = true; return }
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
    else if (t === "o" || t === "O") outlineWanted = !outlineWanted
    else if (t === "v" || t === "V") { if (hasHistory) toggleList() }
    else if (t === "f" || t === "F") { if (comparing && changes.total > 0) changes.foldOn = !changes.foldOn }
    else if (t === "n" && finder.query) finder.go(finder.current + 1)
    else if (t === "N" && finder.query) finder.go(finder.current - 1)
    else if (t === "n" && comparing) step(1)
    else if (t === "p" && comparing) step(-1)
    else if (t === "/") { findShown = true; findBar.focusField() }
    else if (k === Qt.Key_Escape) {
      if (findShown) closeFind()
      else if (ctx.selectionOwner) { ctx.selectionOwner.deselect(); ctx.selectionOwner = null }
      else if (comparing) stopComparing()
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
      hasHistory: win.hasHistory
      dirty: win.versions.dirty
      comparing: win.comparing
      listOpen: win.listShown
      from: changes.from
      to: changes.to
      total: changes.total
      foldOn: changes.foldOn
      onToggleOutline: win.outlineWanted = !win.outlineWanted
      onToggleWide: win.wide = !win.wide
      onToggleFind: { if (win.findShown) win.closeFind(); else { win.findShown = true; findBar.focusField() } }
      onCopyAll: ctx.copyText(doc.source, "Copied the whole file")
      onShowHelp: win.helpShown = true
      onToggleVersions: win.toggleList()
      onToggleFold: if (changes.total > 0) changes.foldOn = !changes.foldOn
      onStopComparing: win.stopComparing()
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
      visible: doc.missing || changes.banner !== ""
      text: doc.missing ? win.fileName + " was deleted or moved. Showing the last version; it reappears if the file comes back." : changes.banner
      tone: doc.missing ? Theme.yellow : Theme.blue
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
        blocks: win.comparing ? doc.blocks : []
        dimUnchanged: changes.foldOn
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
        changes: changes.shown
        documentName: win.fileName
        wide: win.wide
        onNotice: t => toast.show(t)
        onOpenFile: (p, a) => win.openFile(p, a)
        onUnfoldRequested: i => changes.unfold(doc.blocks, i)
      }

      // A brief tint over the change n/p landed on.
      Rectangle {
        id: flash
        property int target: -1
        visible: opacity > 0
        opacity: 0
        z: 4
        radius: Math.max(6, Style.cornerRadius)
        color: Util.alpha(Theme.accent, Theme.light ? 0.1 : 0.13)
        Behavior on opacity { NumberAnimation { duration: Reading.motion(500); easing.type: Easing.OutQuad } }
      }
      Timer {
        id: flashTimer
        interval: 300
        onTriggered: {
          var item = view.itemAtIndex(flash.target)
          if (!item) return
          var p = item.mapToItem(body, 0, 0)
          flash.x = md.x + view.gutter - Style.space(12)
          flash.y = p.y + item.gap - Style.space(6)
          flash.width = view.column + Style.space(24)
          flash.height = item.height - item.gap + Style.space(12)
          flash.opacity = 1
          flashOff.restart()
        }
      }
      Timer { id: flashOff; interval: 350; onTriggered: flash.opacity = 0 }

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

    // Click outside the version list closes it.
    MouseArea {
      anchors.fill: parent
      z: 5
      visible: win.listShown
      onClicked: { win.listShown = false; win.picking = "from" }
    }

    VersionList {
      z: 6
      visible: win.listShown
      x: Math.max(Style.space(8), Math.min(header.listRight - width, parent.width - width - Style.space(8)))
      y: header.listBottom + Style.space(6)
      history: win.versions.history || []
      shortcuts: win.versions.shortcuts || []
      currentSha: changes.from && changes.from.sha ? changes.from.sha : ""
      picking: win.picking
      onPick: spec => win.pickVersion(spec)
      onPickTwo: win.picking = "to"
      onCloseRequested: { win.listShown = false; win.picking = "from" }
    }

    ShortcutSheet {
      anchors.fill: parent
      z: 7
      visible: win.helpShown
      changes: win.hasHistory
      onCloseRequested: win.helpShown = false
    }

    Toast { id: toast; z: 8 }

    // Drop a Markdown file anywhere on the window.
    DropArea {
      anchors.fill: parent
      z: 9
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
}
