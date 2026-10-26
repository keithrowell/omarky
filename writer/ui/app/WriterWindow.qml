import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components
import "../lib/editing.js" as E

// One window per document: the editor, a header that steps aside while
// you type, the word count, find, the preview (OmarkyReader's renderer), and
// saving as you go. The editor itself is Omarky's.
FloatingWindow {
  id: win

  property string path: ""
  // Open with the cursor after the last character (capture notes).
  property bool startAtEnd: false
  // The file this window has now (path is only where it started).
  readonly property string filePath: buffer.path
  readonly property bool draft: Settings.isDraft(buffer.path)
  readonly property string fileName: draft ? "Untitled" : buffer.path.split("/").pop()
  readonly property string dir: buffer.path ? buffer.path.slice(0, buffer.path.lastIndexOf("/")) : ""
  readonly property string folderLabel: {
    if (draft) return "draft"
    var home = Quickshell.env("HOME")
    return dir.indexOf(home) === 0 ? "~" + dir.slice(home.length) : dir
  }
  readonly property Item grabRoot: page
  readonly property bool dirty: editor.text !== buffer.savedText

  property bool previewShown: false
  property bool findShown: false
  property bool helpShown: false
  property string diskText: ""
  property bool conflict: false
  property var counts: ({ words: 0, chars: 0, minutes: 0 })

  signal openFile(string path)
  signal newWindow()
  signal closeRequested()

  title: "OmarkyWriter — " + fileName
  implicitWidth: Style.space(1100)
  implicitHeight: Style.space(900)
  color: Theme.bg

  onClosed: finish()

  // Last save on the way out; an emptied draft leaves no file behind.
  function finish() {
    if (draft && editor.text.trim() === "") { buffer.remove(); return }
    if (dirty) buffer.save(editor.text)
  }

  function toEnd() {
    editor.textEdit.cursorPosition = editor.text.length
    editor.follow(true)
    editor.forceFocus()
  }

  function save() {
    if (draft) { saveDialog.open(); return }
    buffer.save(editor.text)
    toast.show("Saved")
  }

  // Switch this window to another file (an empty draft window opening one).
  function load(p) {
    if (draft && editor.text.trim() === "") buffer.remove()
    buffer.loaded = false
    buffer.savedText = ""
    buffer.path = p
  }

  function showPreview(on) {
    if (on === previewShown) return
    if (on) {
      previewText.restart()
      preview.markdown = editor.text
      previewShown = true
      Qt.callLater(syncPreview)
    } else {
      previewShown = false
      editor.forceFocus()
    }
  }

  // Open the preview at the block the cursor is in.
  function syncPreview() {
    var line = editor.cursorLine()
    var blocks = preview.doc.blocks
    var best = 0
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].srcStart !== undefined && blocks[i].srcStart <= line) best = i
      else if (blocks[i].srcStart > line) break
    }
    if (best > 0) preview.view.scrollToIndex(best, false)
  }

  // ---- find
  property var matches: []
  property int matchIndex: -1

  function runFind(query, from) {
    matches = E.findAll(editor.text, query)
    if (matches.length === 0) { matchIndex = -1; return }
    var at = from === undefined ? editor.textEdit.selectionStart : from
    var i = 0
    while (i < matches.length && matches[i] < at) i++
    matchIndex = i % matches.length
    showMatch()
  }

  function stepFind(dir) {
    if (matches.length === 0) return
    matchIndex = (matchIndex + dir + matches.length) % matches.length
    showMatch()
  }

  function showMatch() {
    var s = matches[matchIndex]
    editor.selectRange(s, s + findInput.text.length)
  }

  function command(name) {
    switch (name) {
    case "save": save(); break
    case "saveAs": saveDialog.open(); break
    case "new": win.newWindow(); break
    case "open": openDialog.open(); break
    case "close": win.closeRequested(); break
    case "preview": showPreview(!previewShown); break
    case "focus": Settings.set("focus", !Settings.focus); toast.show(Settings.focus ? "Focus on" : "Focus off"); break
    case "typewriter": Settings.set("typewriter", !Settings.typewriter); toast.show(Settings.typewriter ? "Typewriter on" : "Typewriter off"); Qt.callLater(function() { editor.follow(true) }); break
    case "spell": Settings.set("spell", !Settings.spell); toast.show(Settings.spell ? "Spelling on" : "Spelling off"); break
    case "font": Settings.nextFont(); toast.show(Settings.font); break
    case "zoomIn": Settings.setZoom(Settings.zoom + 0.1); break
    case "zoomOut": Settings.setZoom(Settings.zoom - 0.1); break
    case "find":
      findShown = true
      if (editor.textEdit.selectedText) findInput.text = editor.textEdit.selectedText
      findInput.forceActiveFocus()
      findInput.selectAll()
      break
    case "findNext": if (findInput.text) { if (!matches.length) runFind(findInput.text); else stepFind(1) } break
    case "findPrev": stepFind(-1); break
    case "help": helpShown = !helpShown; break
    case "rewrite": rewriter.open("block"); break
    case "rewriteSection": rewriter.open("section"); break
    case "recent": listDrafts.running = true; break
    case "escape":
      if (menu.shown) menu.close()
      else if (rewriter.shown) rewriter.dismiss()
      else if (helpShown) helpShown = false
      else if (findShown) { findShown = false; editor.forceFocus() }
      else if (previewShown) showPreview(false)
      break
    }
  }

  Buffer {
    id: buffer
    path: win.path || Settings.newDraftPath()
    onOpened: text => {
      editor.text = text
      editor.textEdit.cursorPosition = win.startAtEnd ? text.length : 0
      if (win.startAtEnd) Qt.callLater(function() { editor.follow(true) })
      win.counts = E.stats(text)
      if (!win.draft) Settings.addRecent(path)
      editor.forceFocus()
    }
    onChangedOnDisk: text => {
      // Ours to take when nothing here is unsaved; otherwise ask.
      if (editor.text === buffer.savedText) {
        var pos = editor.textEdit.cursorPosition
        buffer.savedText = text
        editor.text = text
        editor.textEdit.cursorPosition = Math.min(pos, text.length)
        toast.show("Reloaded from disk")
      } else {
        win.diskText = text
        win.conflict = true
      }
    }
  }

  // Saving as you go: a moment after typing stops. A draft is only written
  // once it has something in it.
  Timer {
    id: autosave
    interval: 900
    onTriggered: {
      if (!win.dirty) return
      if (win.draft && editor.text.trim() === "") return
      buffer.save(editor.text)
    }
  }

  Timer { id: countTimer; interval: 250; onTriggered: win.counts = E.stats(editor.text) }
  Timer {
    id: previewText
    interval: 200
    onTriggered: if (win.previewShown) preview.markdown = editor.text
  }

  FileDialog {
    id: openDialog
    title: "Open a Markdown file"
    nameFilters: ["Markdown (*.md *.markdown *.mdown *.mkd *.txt)", "All files (*)"]
    currentFolder: "file://" + (win.draft || !win.dir ? Quickshell.env("HOME") : win.dir)
    onAccepted: {
      var p = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
      win.openOrLoad(p)
    }
  }

  FileDialog {
    id: saveDialog
    title: "Save as"
    fileMode: FileDialog.SaveFile
    defaultSuffix: "md"
    nameFilters: ["Markdown (*.md)", "All files (*)"]
    currentFolder: "file://" + (win.draft || !win.dir ? Quickshell.env("HOME") + "/Documents" : win.dir)
    onAccepted: {
      var p = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
      saveAs.target = p
      saveAs.wasDraft = win.draft ? buffer.path : ""
      saveAs.path = p
      saveAs.setText(editor.text)
    }
  }

  // Writes the new file, then the window follows it there.
  FileView {
    id: saveAs
    property string target: ""
    property string wasDraft: ""
    printErrors: false
    atomicWrites: true
    blockLoading: true
    onSaved: {
      if (wasDraft) rmDraft.command = ["rm", "-f", "--", wasDraft]
      if (wasDraft) rmDraft.running = true
      buffer.loaded = true
      buffer.savedText = editor.text
      buffer.path = target
      Settings.addRecent(target)
      toast.show("Saved as " + target.split("/").pop())
    }
    onSaveFailed: err => toast.show("Could not save: " + err)
  }
  Process { id: rmDraft }

  // Ctrl+R: recent files and drafts (newest first) in one list, opened
  // from the file name.
  Process {
    id: listDrafts
    command: ["sh", "-c", 'ls -t "$1"/*.md 2>/dev/null | head -12 | while IFS= read -r f; do ' +
              'printf "%s\t%s\t%s\n" "$f" "$(date -r "$f" "+%-d %b %H:%M")" "$(grep -m1 "[^[:space:]]" "$f" | sed "s/^#* *//" | cut -c1-48)"; done',
              "sh", Settings.draftsDir]
    stdout: StdioCollector {
      onStreamFinished: {
        var items = []
        var home = Quickshell.env("HOME")
        var recent = Settings.recent.filter(function(p) { return p !== buffer.path }).slice(0, 10)
        for (var i = 0; i < recent.length; i++) {
          var p = recent[i], d = p.slice(0, p.lastIndexOf("/"))
          items.push({ label: p.split("/").pop(), keys: d.indexOf(home) === 0 ? "~" + d.slice(home.length) : d,
                       run: (function(path) { return function() { win.openOrLoad(path) } })(p) })
        }
        var drafts = text.split("\n").filter(function(l) { return l.trim() !== "" })
        var shown = 0
        for (var j = 0; j < drafts.length; j++) {
          var f = drafts[j].split("\t")
          if (f[0] === buffer.path) continue
          if (shown++ === 0 && items.length) items.push({ separator: true })
          items.push({ label: f[2] || "Untitled", keys: "draft · " + f[1],
                       run: (function(path) { return function() { win.openOrLoad(path) } })(f[0]) })
        }
        if (items.length === 0) items.push({ label: "Nothing recent yet", disabled: true })
        menu.open(Style.space(12), header.height - Style.space(4), items)
      }
    }
  }

  // An empty draft window becomes the file; otherwise a new window opens.
  function openOrLoad(p) {
    if (draft && editor.text.trim() === "") load(p)
    else openFile(p)
  }

  Item {
    id: page
    anchors.fill: parent

    Rectangle { anchors.fill: parent; color: Theme.bg }

    Editor {
      id: editor
      anchors.fill: parent
      visible: !win.previewShown
      focusMode: Settings.focus
      typewriter: Settings.typewriter
      spellCheck: Settings.spell
      family: Settings.font
      zoom: Settings.zoom
      onCommand: name => win.command(name)
      onContextMenu: (x, y, items) => menu.open(x, y, items)
      textEdit.onTextChanged: {
        autosave.restart()
        countTimer.restart()
        if (win.previewShown) previewText.restart()
        if (win.findShown && findInput.text) win.matches = E.findAll(editor.text, findInput.text)
      }
    }

    MarkdownView {
      id: preview
      anchors.fill: parent
      anchors.topMargin: header.height
      visible: win.previewShown
      opacity: win.previewShown ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Reading.motion(160) } }
      baseUrl: win.dir
      keepPlace: true
      documentName: win.fileName
      onNotice: text => toast.show(text)
      onOpenFile: (p, a) => win.openFile(p)
      focus: win.previewShown
      Keys.onPressed: event => {
        var ctrl = event.modifiers & Qt.ControlModifier
        if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_P)) { win.showPreview(false); event.accepted = true }
        else if (ctrl && event.key === Qt.Key_S) { win.save(); event.accepted = true }
      }
    }

    // Text fades into the page at both edges rather than being cut off.
    Rectangle {
      visible: !win.previewShown
      y: header.opacity > 0.5 ? header.height : 0
      width: parent.width
      height: Style.space(28)
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.bg }
        GradientStop { position: 1; color: Util.alpha(Theme.bg, 0) }
      }
    }
    Rectangle {
      visible: !win.previewShown
      anchors.bottom: parent.bottom
      width: parent.width
      height: Style.space(64)
      gradient: Gradient {
        GradientStop { position: 0; color: Util.alpha(Theme.bg, 0) }
        GradientStop { position: 0.6; color: Theme.bg }
      }
    }

    // ---- the header: steps aside while you type, back on a mouse move
    HoverHandler { id: pageHover }
    property real lastMove: 0
    readonly property bool chrome: !editor.typing || headerHover.hovered || win.previewShown || win.findShown || win.conflict

    Rectangle {
      id: header
      width: parent.width
      height: Style.space(44)
      color: Theme.bg
      opacity: page.chrome ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Reading.motion(page.chrome ? 160 : 600) } }
      HoverHandler { id: headerHover }

      Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 1
        color: Theme.hairlineSoft
        opacity: win.previewShown || editor.progress > 0.002 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Reading.motion(200) } }
      }

      Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)
        Text {
          id: nameLabel
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, header.width * 0.4)
          elide: Text.ElideMiddle
          text: win.fileName
          textFormat: Text.PlainText
          color: win.draft ? Theme.dim : Theme.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          TapHandler { onTapped: win.command("recent") }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, Math.min(implicitWidth, header.width - nameLabel.width - right.width - Style.space(90)))
          elide: Text.ElideLeft
          text: win.folderLabel
          textFormat: Text.PlainText
          color: Theme.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(6); height: width; radius: width / 2
          color: buffer.error ? Theme.red : Theme.faint
          visible: win.dirty || buffer.error !== ""
        }
      }

      Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        ChipButton { icon: ""; size: Style.font.body; active: win.findShown; onClicked: win.command("find"); tip: "Find  Ctrl+F" }
        ChipButton { icon: ""; size: Style.font.body; onClicked: win.command("font"); tip: "Font  Ctrl+Shift+M" }
        ChipButton { icon: ""; size: Style.font.body; active: Settings.focus; onClicked: win.command("focus"); tip: "Focus  Ctrl+Shift+F" }
        ChipButton { icon: ""; size: Style.font.body; active: Settings.typewriter; onClicked: win.command("typewriter"); tip: "Typewriter  Ctrl+Shift+T" }
        ChipButton { icon: ""; size: Style.font.body; active: win.previewShown; onClicked: win.command("preview"); tip: "Preview  Ctrl+P" }
        ChipButton { icon: ""; size: Style.font.body; active: win.helpShown; onClicked: win.command("help"); tip: "Shortcuts  Ctrl+/" }
      }
    }

    // Changed on disk while there are unsaved edits here.
    Rectangle {
      id: banner
      visible: win.conflict
      y: header.height
      width: parent.width
      height: Style.space(40)
      color: Util.alpha(Theme.yellow, Theme.light ? 0.1 : 0.09)
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Util.alpha(Theme.yellow, 0.25) }
      Row {
        anchors.centerIn: parent
        spacing: Style.space(10)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "The file changed on disk."
          color: Theme.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        ChipButton {
          anchors.verticalCenter: parent.verticalCenter
          label: "Load theirs"
          size: Style.font.bodySmall
          onClicked: {
            buffer.savedText = win.diskText
            editor.text = win.diskText
            win.conflict = false
          }
        }
        ChipButton {
          anchors.verticalCenter: parent.verticalCenter
          label: "Keep mine"
          size: Style.font.bodySmall
          onClicked: { win.conflict = false; buffer.save(editor.text) }
        }
      }
    }

    // ---- find
    Rectangle {
      id: findBar
      visible: win.findShown
      anchors.right: parent.right
      anchors.rightMargin: Style.space(16)
      y: header.height + Style.space(10)
      width: Style.space(340)
      height: Style.space(40)
      radius: Math.max(6, Style.cornerRadius)
      color: ShellColor.popups.background
      border.width: 1
      border.color: Theme.hairline

      Glyph {
        id: findIcon
        x: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        size: Style.font.bodySmall
        color: Theme.faint
      }
      TextInput {
        id: findInput
        anchors.left: findIcon.right
        anchors.leftMargin: Style.space(8)
        anchors.right: findCount.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.selection
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        onTextChanged: win.runFind(text, editor.textEdit.selectionStart)
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.stepFind(event.modifiers & Qt.ShiftModifier ? -1 : 1); event.accepted = true }
          else if (event.key === Qt.Key_Escape) { win.command("escape"); event.accepted = true }
          else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) { selectAll(); event.accepted = true }
        }
      }
      Text {
        id: findCount
        anchors.right: parent.right
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        text: findInput.text === "" ? "" : win.matches.length === 0 ? "none" : (win.matchIndex + 1) + " of " + win.matches.length
        color: win.matches.length === 0 && findInput.text !== "" ? Theme.red : Theme.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    // ---- the count: words, and more on hover
    Text {
      id: counter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(14)
      anchors.horizontalCenter: parent.horizontalCenter
      visible: !win.previewShown
      readonly property var sel: editor.textEdit.selectedText ? E.stats(editor.textEdit.selectedText) : null
      text: {
        function n(x) { return Number(x).toLocaleString(Qt.locale("en_AU"), "f", 0) }
        if (sel) return n(sel.words) + " of " + n(win.counts.words) + " words selected"
        var w = n(win.counts.words) + (win.counts.words === 1 ? " word" : " words")
        if (!countHover.hovered) return w
        return w + "   ·   " + n(win.counts.chars) + " characters   ·   " + win.counts.minutes + " min read"
      }
      color: countHover.hovered ? Theme.dim : Theme.faint
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      opacity: page.chrome || sel ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Reading.motion(page.chrome ? 160 : 600) } }
      HoverHandler { id: countHover }
    }

    // Progress along the top edge, as in 
    Rectangle {
      height: 2
      width: parent.width * (win.previewShown ? preview.progress : editor.progress)
      color: Theme.accent
      opacity: 0.55
      visible: width > 1
    }

    Rewriter {
      id: rewriter
      editor: editor
      ctx: preview.ctx
      bin: Quickshell.env("OMARKY_WRITER_BIN") || (Quickshell.shellDir.replace(/\/writer\/ui$/, "") + "/bin/omarky")
      path: buffer.path
      stateDir: Settings.dir
      visible: shown && !win.previewShown
      onNotice: text => toast.show(text)
    }

    HelpSheet {
      anchors.fill: parent
      rewrite: rewriter.available
      visible: win.helpShown
      onCloseRequested: { win.helpShown = false; editor.forceFocus() }
    }

    PopupMenu {
      id: menu
      onClosed: editor.forceFocus()
    }

    Toast { id: toast }
  }

  // Dev hooks for tools/ checks.
  function debugState() {
    return {
      path: buffer.path, draft: draft, dirty: dirty, words: counts.words, preview: previewShown,
      focus: Settings.focus, typewriter: Settings.typewriter, font: Settings.font,
      cursor: editor.textEdit.cursorPosition, length: editor.text.length, highlighted: editor.highlighted,
      spell: editor.highlighter ? editor.highlighter.spellAvailable : false
    }
  }
  function debugType(s) { editor.textEdit.insert(editor.textEdit.cursorPosition, s) }
  function debugCursor(p) { editor.textEdit.cursorPosition = p; editor.follow(true) }
  // "Return", "Tab", "shift+Tab", "ctrl+b": the editor's own key handling.
  function debugKey(spec) {
    var parts = String(spec).split("+"), name = parts.pop(), mods = 0
    if (parts.indexOf("ctrl") >= 0) mods |= Qt.ControlModifier
    if (parts.indexOf("shift") >= 0) mods |= Qt.ShiftModifier
    var keys = { Return: Qt.Key_Return, Tab: Qt.Key_Tab, Backtab: Qt.Key_Backtab, Escape: Qt.Key_Escape }
    var key = keys[name] !== undefined ? keys[name] : name.toUpperCase().charCodeAt(0)
    if (name === "Tab" && (mods & Qt.ShiftModifier)) key = Qt.Key_Backtab
    var ev = { key: key, modifiers: mods, accepted: false }
    editor.handleKey(ev)
    if (!ev.accepted && key === Qt.Key_Return) debugType("\n")
  }
  function debugText() { return editor.text }
  function debugRewrite(kind) { rewriter.open(kind || "block"); return rewriter.debugState() }
  function debugRewriteState() { return rewriter.debugState() }
  function debugRewriteSay(s) { rewriter.debugInstruction(s); return rewriter.debugKey("Return") }
  function debugRewriteKey(spec) { return rewriter.debugKey(spec) }
  function debugUndo() { editor.textEdit.undo(); return editor.text }
  function debugSelect(a, b) { editor.textEdit.select(a, b) }
}
