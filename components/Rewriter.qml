import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services
import "../lib/ranges.js" as R
import "../lib/diff/changes.js" as Changes

// Ctrl+J in an Editor: an instruction line under a block, a section or a
// selection, and Claude's rewrite in a card under it with the changed words
// marked. Enter takes the rewrite as one undo step, Esc drops it, another
// instruction refines it. Claude runs behind the launcher (`omarky rewrite`,
// decision 0019); this item only writes the job and reads the stream.
//
// The host fills `container` (where the card may sit), `editor`, `ctx` (a
// MarkdownView's, for drawing blocks), `bin` (the omarky command) and
// `stateDir`, and forwards the editor's "rewrite", "rewriteSection" and
// "escape" commands to open() and dismiss().
Item {
  id: root
  anchors.fill: parent
  visible: shown
  z: 20

  required property Item editor
  property var ctx: null
  property string bin: ""
  property string path: ""
  property string stateDir: ""

  property bool available: false
  property bool shown: false
  // What is being rewritten: offsets into the editor's text, and the text
  // they held when the line opened.
  property var range: ({ start: 0, end: 0, kind: "block" })
  property string original: ""
  property int caret: 0
  property bool lost: false
  // This conversation: the instructions sent and the rewrites that came back.
  property var turns: []
  property string lastInstruction: ""
  property var rewrites: []
  property int shownRewrite: -1
  property string proposal: ""
  property bool busy: false
  property string status: ""
  property var notes: []
  property string problem: ""
  property var history: []
  property int historyIndex: -1

  signal notice(string text)

  readonly property bool ready: proposal !== "" && !busy
  readonly property string kindLabel: ({ selection: "selection", block: "block", section: "section", document: "whole document" })[range.kind] || range.kind

  // ---- opening and widening

  function open(kind) {
    if (!available) { notice("Rewrite needs Claude Code (claude on your PATH)"); return }
    var t = editor.text, te = editor.textEdit
    if (shown && !busy) {
      if (kind === "section") setRange(R.sectionAt(t, caret))
      else setRange(R.widen(t, range, caret))
    } else if (!shown) {
      caret = te.cursorPosition
      if (kind === "section") setRange(R.sectionAt(t, caret))
      else if (te.selectionEnd > te.selectionStart) setRange(R.words(t, te.selectionStart, te.selectionEnd))
      else setRange(R.blockAt(t, caret))
      shown = true
      input.text = ""
      historyIndex = -1
    }
    input.forceActiveFocus()
  }

  function setRange(r) {
    range = r
    original = editor.text.slice(r.start, r.end)
    lost = false
    clearConversation()
    shade()
  }

  function clearConversation() {
    turns = []
    rewrites = []
    shownRewrite = -1
    proposal = ""
    lastInstruction = ""
    notes = []
    problem = ""
    status = ""
  }

  function shade() {
    editor.shadeStart = shown && !lost ? range.start : -1
    editor.shadeEnd = shown && !lost ? range.end : -1
  }
  onShownChanged: shade()

  function close() {
    if (busy) stop()
    shown = false
    clearConversation()
    editor.shadeStart = -1
    editor.forceFocus()
  }

  // Esc: stop Claude, then drop the rewrite and close.
  function dismiss() {
    if (busy) { stop(); status = "Stopped"; return }
    close()
  }

  // The range follows edits elsewhere in the text while the line is open.
  Connections {
    target: root.editor.textEdit
    function onTextChanged() {
      if (!root.shown) return
      var p = R.locate(root.editor.text, root.original, root.range.start)
      root.lost = p < 0
      if (p >= 0 && p !== root.range.start) root.range = { start: p, end: p + root.original.length, kind: root.range.kind, level: root.range.level }
      root.shade()
    }
  }

  // ---- sending

  function send(instruction) {
    instruction = instruction.trim()
    if (instruction === "" || busy) return
    if (lost) { problem = "That text changed. Press Esc and select it again."; return }
    if (proposal !== "") turns = turns.concat([{ instruction: lastInstruction, rewrite: proposal }])
    lastInstruction = instruction
    remember(instruction)
    input.text = ""
    historyIndex = -1
    proposal = ""
    notes = []
    problem = ""
    status = "Writing"
    busy = true
    var job = { path: root.path, document: editor.text, start: range.start, end: range.end, instruction: instruction, turns: turns }
    jobFile.path = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarky-rewrite-" + Date.now() + "-" + Math.floor(Math.random() * 1e6) + ".json"
    jobFile.setText(JSON.stringify(job))
  }

  function stop() {
    if (proc.running) proc.signal(15)
    busy = false
  }

  function handle(m) {
    if (m.type === "text") { proposal += m.text; drawSoon.restart() }
    else if (m.type === "checking") status = "Checking against your writing guide"
    else if (m.type === "retry") { proposal = ""; status = "Fixing: " + m.notes.join(", ") }
    else if (m.type === "done") {
      busy = false
      proposal = m.text
      rewrites = rewrites.concat([m.text])
      shownRewrite = rewrites.length - 1
      notes = m.notes || []
      status = m.text === original ? "No change" : ""
      drawNow()
    } else if (m.type === "error") {
      busy = false
      problem = m.message
      status = ""
    }
  }

  // ---- taking the rewrite

  function accept() {
    if (!ready) return
    var p = R.locate(editor.text, original, range.start)
    if (p < 0) {
      Quickshell.clipboardText = proposal
      problem = "The text changed while Claude worked, so nothing was replaced. The rewrite is on the clipboard."
      return
    }
    var text = proposal
    shown = false
    clearConversation()
    editor.shadeStart = -1
    editor.replace(p, p + original.length, text)
    editor.forceFocus()
  }

  function step(dir) {
    if (busy || rewrites.length < 2) return
    shownRewrite = Math.max(0, Math.min(rewrites.length - 1, shownRewrite + dir))
    proposal = rewrites[shownRewrite]
    drawNow()
  }

  function handleKey(event) {
    var ctrl = event.modifiers & Qt.ControlModifier, alt = event.modifiers & Qt.AltModifier, shift = event.modifiers & Qt.ShiftModifier
    var k = event.key
    if (k === Qt.Key_Return || k === Qt.Key_Enter) {
      if (input.text.trim() !== "") send(input.text)
      else accept()
      event.accepted = true
    } else if (k === Qt.Key_Escape) { dismiss(); event.accepted = true }
    else if (ctrl && k === Qt.Key_J) { open(shift ? "section" : "widen"); event.accepted = true }
    else if (alt && (k === Qt.Key_Up || k === Qt.Key_Down)) { step(k === Qt.Key_Up ? -1 : 1); event.accepted = true }
    else if (!alt && !ctrl && (k === Qt.Key_Up || k === Qt.Key_Down) && (input.text === "" || historyIndex >= 0)) {
      if (recall(k === Qt.Key_Up ? 1 : -1)) event.accepted = true
    }
  }

  // ---- remembered instructions (Up and Down on an empty line)

  function remember(s) {
    history = [s].concat(history.filter(function(h) { return h !== s })).slice(0, 40)
    if (stateDir) historyFile.setText(JSON.stringify(history))
  }

  function recall(dir) {
    if (history.length === 0) return false
    var i = Math.max(-1, Math.min(history.length - 1, historyIndex + dir))
    if (i === historyIndex) return true
    historyIndex = i
    input.text = i < 0 ? "" : history[i]
    input.cursorPosition = input.text.length
    return true
  }

  FileView {
    id: historyFile
    path: root.stateDir ? root.stateDir + "/instructions.json" : ""
    printErrors: false
    atomicWrites: true
    onLoaded: { try { var a = JSON.parse(text()); if (Array.isArray(a)) root.history = a } catch (e) {} }
  }

  FileView {
    id: jobFile
    printErrors: false
    onSaved: { proc.command = [root.bin, "rewrite", "--job", path]; proc.running = true }
    onSaveFailed: err => { root.busy = false; root.problem = "Could not start the rewrite: " + err }
  }

  Process {
    id: proc
    stdout: SplitParser {
      onRead: line => { try { root.handle(JSON.parse(line)) } catch (e) {} }
    }
    onExited: (code, status) => {
      if (root.busy) { root.busy = false; if (!root.problem && root.status !== "Stopped") root.problem = "The rewrite stopped (exit " + code + ")." }
    }
  }

  Process {
    id: availability
    onExited: (code, status) => root.available = code === 0
  }
  Component.onCompleted: if (bin) { availability.command = [bin, "rewrite", "--available"]; availability.running = true }

  // ---- drawing: the rewrite as the reader marks changes

  property var marked: []
  function drawNow() { drawSoon.stop(); marked = proposal === "" ? [] : Changes.rewrite(original, proposal) }
  Timer { id: drawSoon; interval: 90; onTriggered: root.drawNow() }

  readonly property real pad: Style.space(16)
  // Where the range is, in this item's coordinates.
  readonly property point origin: { void editor.x; void editor.y; void editor.height; void root.width; void root.height; return editor.mapToItem(root, 0, 0) }
  readonly property var box: shown ? editor.rangeBox(range.start, range.end) : null
  readonly property real margin: Style.space(12)

  Rectangle {
    id: panel
    visible: root.box !== null
    width: Math.min(root.width - root.margin * 2, (root.box ? root.box.width : root.editor.measure) + root.pad * 2)
    x: Math.max(root.margin, Math.min(root.width - width - root.margin, root.origin.x + (root.box ? root.box.x : 0) - root.pad))
    readonly property real below: root.origin.y + (root.box ? root.box.y + root.box.height : 0) + Style.space(14)
    readonly property real above: root.origin.y + (root.box ? root.box.y : 0) - Style.space(14) - height
    y: {
      var room = root.height - root.margin
      if (below + height <= room) return below
      if (above >= root.margin) return above
      return Math.max(root.margin, room - height)
    }
    height: col.height + root.pad * 2
    radius: Math.max(6, Style.cornerRadius)
    color: ShellColor.popups.background
    border.width: 1
    border.color: Theme.hairline
    MouseArea { anchors.fill: parent; onPressed: input.forceActiveFocus() }

    Column {
      id: col
      x: root.pad
      y: root.pad
      width: parent.width - root.pad * 2
      spacing: Style.space(10)

      // The instruction line.
      Item {
        width: parent.width
        height: Math.max(input.implicitHeight, Style.space(26))
        Text {
          id: prompt
          anchors.verticalCenter: parent.verticalCenter
          text: "Rewrite the " + root.kindLabel
          color: Theme.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        TextInput {
          id: input
          anchors.left: prompt.right
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          clip: true
          color: Theme.text
          selectionColor: Theme.selection
          font.family: Reading.prose
          font.styleName: "Regular"
          font.pixelSize: Math.round(Reading.body * 0.92)
          Text {
            visible: input.text === ""
            text: root.ready ? "Enter to use it, or say what else to change" : root.busy ? "" : "Say what to change"
            color: Theme.ghost
            font: input.font
          }
          Keys.onPressed: event => root.handleKey(event)
        }
      }

      // The rewrite, marked against the original.
      Rectangle { visible: card.visible; width: parent.width; height: 1; color: Theme.hairlineSoft }
      Flickable {
        id: card
        visible: root.marked.length > 0
        width: parent.width
        height: Math.min(stack.height, Math.max(Style.space(80), root.height * 0.45))
        contentHeight: stack.height
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: stack
          x: Math.round((card.width - width) / 2)
          width: card.width
          spacing: Math.round(Reading.body * 0.7)
          Repeater {
            model: root.marked
            Item {
              required property var modelData
              width: stack.width
              height: blk.height
              Rectangle {
                visible: modelData.change === "added" || modelData.change === "removed"
                x: -Style.space(8); y: -Style.space(4)
                width: parent.width + Style.space(16); height: parent.height + Style.space(8)
                radius: Math.max(4, Style.cornerRadius - 2)
                color: modelData.change === "added" ? Theme.flat(Theme.green, Theme.light ? 0.1 : 0.15) : Theme.flat(Theme.red, Theme.light ? 0.08 : 0.12)
              }
              Block { id: blk; width: parent.width; block: modelData; ctx: root.ctx }
            }
          }
        }
      }

      Text {
        visible: root.notes.length > 0 && !root.busy
        width: parent.width
        wrapMode: Text.Wrap
        text: "Your checker still flags: " + root.notes.join(", ")
        color: Theme.yellow
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      // Status and keys.
      Item {
        width: parent.width
        height: Style.space(22)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          width: parent.width - keyRow.width - Style.space(12)
          elide: Text.ElideRight
          text: root.problem !== "" ? root.problem : root.lost ? "That text changed while the line was open" : root.status !== "" ? root.status + (root.busy ? "…" : "") : root.rewrites.length > 1 ? "Rewrite " + (root.shownRewrite + 1) + " of " + root.rewrites.length : ""
          color: root.problem !== "" || root.lost ? Theme.red : Theme.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            onRunningChanged: if (!running) parent.opacity = 1
            NumberAnimation { to: 0.45; duration: Reading.motion(700) }
            NumberAnimation { to: 1; duration: Reading.motion(700) }
          }
        }
        Row {
          id: keyRow
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)
          KeyCap { visible: root.ready; keys: "Enter"; anchors.verticalCenter: parent.verticalCenter }
          Text { visible: root.ready; text: "use"; color: Theme.faint; font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
          Item { visible: root.ready; width: Style.space(6); height: 1 }
          KeyCap { visible: !root.busy && !root.ready; keys: "Ctrl+J"; anchors.verticalCenter: parent.verticalCenter }
          Text { visible: !root.busy && !root.ready; text: "wider"; color: Theme.faint; font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
          Item { visible: !root.busy && !root.ready; width: Style.space(6); height: 1 }
          KeyCap { keys: "Esc"; anchors.verticalCenter: parent.verticalCenter }
          Text { text: root.busy ? "stop" : root.ready ? "drop" : "close"; color: Theme.faint; font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
        }
      }
    }
  }

  // Dev hooks for the offscreen checks.
  function debugState() {
    return { available: available, shown: shown, kind: range.kind, start: range.start, end: range.end, original: original,
             busy: busy, proposal: proposal, status: status, problem: problem, notes: notes, rewrites: rewrites.length,
             marked: marked.map(function(b) { return b.change }) }
  }
  function debugInstruction(s) { input.text = s }
  function debugKey(spec) {
    var parts = String(spec).split("+"), name = parts.pop(), mods = 0
    if (parts.indexOf("ctrl") >= 0) mods |= Qt.ControlModifier
    if (parts.indexOf("shift") >= 0) mods |= Qt.ShiftModifier
    if (parts.indexOf("alt") >= 0) mods |= Qt.AltModifier
    var keys = { Return: Qt.Key_Return, Escape: Qt.Key_Escape, Up: Qt.Key_Up, Down: Qt.Key_Down }
    var ev = { key: keys[name] !== undefined ? keys[name] : name.toUpperCase().charCodeAt(0), modifiers: mods, accepted: false }
    handleKey(ev)
    return ev.accepted
  }
}
