import QtQuick
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components

// `E` (a block) or `Shift+E` (a section): the file's own lines in OmarkyWriter's
// editor, on a card over the page, with the blocks around them faint for
// context. Ctrl+Enter splices the text back into the file and writes it
// whole, atomically; Esc leaves the file alone. The reader never holds the
// file open: the page under the sheet reloads from disk like any other
// edit (spec 2026-10-26-block-editing-sheet).
Item {
  id: root
  anchors.fill: parent
  visible: shown
  z: 7

  property bool shown: false
  // The window's parts.
  property var doc: null
  property var ctx: null
  property string path: ""
  property string fileName: ""
  property real zoom: 1
  property real column: Style.space(600)
  // What is being edited: source lines [start, end).
  property int start: -1
  property int end: -1
  property string original: ""
  // The document's source when the sheet opened; a file that changed
  // meanwhile is not written over.
  property string base: ""
  property var before: []
  property var after: []
  // The older wording of a reworded block (changes mode), "" when none.
  property string older: ""
  property string problem: ""
  property bool armed: false
  readonly property bool dirty: editor.text !== original
  readonly property bool highlighted: editor.highlighted
  signal saved()
  signal closed()

  function open(s, e, beforeBlock, afterBlock, olderText) {
    start = s
    end = e
    before = beforeBlock ? [beforeBlock] : []
    after = afterBlock ? [afterBlock] : []
    older = olderText || ""
    problem = ""
    armed = false
    base = doc.source
    original = doc.sourceLines(s, e)
    editor.text = original
    editor.textEdit.cursorPosition = 0
    shown = true
    editor.glide(0, 0)
    editor.forceFocus()
  }

  function cancel() {
    shown = false
    closed()
  }

  function save() {
    if (doc.source !== base) {
      problem = "The file changed while you were editing. Copy your text and open it again."
      return
    }
    var lines = base.split("\n")
    writer.setText(lines.slice(0, start).concat(editor.text.split("\n")).concat(lines.slice(end)).join("\n"))
  }

  function useOlder() {
    editor.text = older
    editor.forceFocus()
  }

  function onCommand(name) {
    if (name === "submit" || name === "save") save()
    else if (name === "escape") {
      if (menu.shown) menu.close()
      else if (!dirty || armed) cancel()
      else { armed = true; armTimer.restart() }
    }
  }

  // Dev hook: "ctrl+enter", "escape", "ctrl+b", "Return"… into the editor.
  function sendKey(spec) {
    var parts = String(spec).split("+"), name = parts.pop(), mods = 0
    if (parts.indexOf("ctrl") >= 0) mods |= Qt.ControlModifier
    if (parts.indexOf("shift") >= 0) mods |= Qt.ShiftModifier
    var keys = { enter: Qt.Key_Return, Return: Qt.Key_Return, escape: Qt.Key_Escape, Tab: Qt.Key_Tab }
    var key = keys[name] !== undefined ? keys[name] : name.toUpperCase().charCodeAt(0)
    var ev = { key: key, modifiers: mods, accepted: false }
    editor.handleKey(ev)
    if (!ev.accepted && key === Qt.Key_Return) editor.textEdit.insert(editor.textEdit.cursorPosition, "\n")
  }
  function type(s) { editor.textEdit.insert(editor.textEdit.cursorPosition, s) }
  function setText(s) { editor.text = s }
  function editorText() { return editor.text }

  Timer { id: armTimer; interval: 2000; onTriggered: root.armed = false }

  FileView {
    id: writer
    path: root.path
    printErrors: false
    atomicWrites: true
    onSaved: { root.shown = false; root.saved(); root.closed() }
    onSaveFailed: err => root.problem = "Could not save: " + err
  }

  // The scrim: modal, so clicks go nowhere.
  Rectangle { anchors.fill: parent; color: Util.alpha(Theme.bg, 0.72) }
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: wheel => wheel.accepted = true }

  readonly property real pad: Style.space(22)
  readonly property real contextMax: Math.round(Reading.body * Reading.lineHeight * 3)
  readonly property real chrome: pad * 2 + title.height + Style.space(10) + keys.height + Style.space(14)
    + (beforeBox.visible ? beforeBox.height + Style.space(10) : 0) + (afterBox.visible ? afterBox.height + Style.space(10) : 0)
    + (olderRow.visible ? olderRow.height + Style.space(10) : 0)
  readonly property real editorHeight: Math.max(Style.space(90), Math.min(editor.contentHeight, Math.round(height * 0.7) - chrome))

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(48), root.column + editor.gutter * 2 + root.pad * 2)
    height: root.chrome + root.editorHeight
    radius: Math.max(6, Style.cornerRadius)
    color: ShellColor.popups.background
    border.width: 1
    border.color: Theme.hairline
    MouseArea { anchors.fill: parent }

    Column {
      id: col
      x: root.pad
      y: root.pad
      width: parent.width - root.pad * 2
      spacing: Style.space(10)

      Row {
        id: title
        width: parent.width
        spacing: Style.space(8)
        Text {
          text: root.fileName
          textFormat: Text.PlainText
          color: Theme.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
        Text {
          text: root.end - root.start === 1 ? "line " + (root.start + 1) : "lines " + (root.start + 1) + " to " + root.end
          color: Theme.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          visible: !editor.highlighted
          text: "plain editor"
          color: Theme.ghost
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      // The block before, its last lines.
      Item {
        id: beforeBox
        visible: root.before.length > 0
        width: parent.width
        height: Math.min(beforeStack.height, root.contextMax)
        clip: true
        Item {
          id: beforeStack
          x: editor.gutter
          width: root.column
          height: childrenRect.height
          y: beforeBox.height - height
          Repeater {
            model: root.before
            Block { required property var modelData; width: beforeStack.width; block: modelData; ctx: root.ctx; look: ({ tier: "dim" }) }
          }
        }
        Rectangle {
          width: parent.width; height: Style.space(28)
          visible: beforeStack.height > root.contextMax
          gradient: Gradient {
            GradientStop { position: 0; color: ShellColor.popups.background }
            GradientStop { position: 1; color: Util.alpha(ShellColor.popups.background, 0) }
          }
        }
        opacity: 0.55
      }

      // Changes mode: the wording on the other side, one chip away.
      Rectangle {
        id: olderRow
        visible: root.older !== ""
        width: parent.width
        height: olderText.implicitHeight + Style.space(16)
        radius: Math.max(4, Style.cornerRadius - 2)
        color: Theme.flat(Theme.red, Theme.light ? 0.06 : 0.1)
        Text {
          id: olderText
          x: Style.space(12)
          y: Style.space(8)
          width: parent.width - useChip.width - Style.space(36)
          text: root.older
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          maximumLineCount: 4
          elide: Text.ElideRight
          color: Theme.dim
          font.family: Reading.prose
          font.pixelSize: Style.font.bodySmall
        }
        ChipButton {
          id: useChip
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          label: "Use this"
          size: Style.font.bodySmall
          onClicked: root.useOlder()
        }
      }

      Editor {
        id: editor
        width: parent.width
        height: root.editorHeight
        zoom: root.zoom
        spellCheck: true
        topPad: Style.space(6)
        bottomPad: Style.space(6)
        onCommand: name => root.onCommand(name)
        onContextMenu: (x, y, items) => { var p = editor.mapToItem(root, x, y); menu.open(p.x, p.y, items) }
      }

      // The block after, its first lines.
      Item {
        id: afterBox
        visible: root.after.length > 0
        width: parent.width
        height: Math.min(afterStack.height, root.contextMax)
        clip: true
        Item {
          id: afterStack
          x: editor.gutter
          width: root.column
          height: childrenRect.height
          Repeater {
            model: root.after
            Block { required property var modelData; width: afterStack.width; block: modelData; ctx: root.ctx; look: ({ tier: "dim" }) }
          }
        }
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width; height: Style.space(28)
          visible: afterStack.height > root.contextMax
          gradient: Gradient {
            GradientStop { position: 0; color: Util.alpha(ShellColor.popups.background, 0) }
            GradientStop { position: 1; color: ShellColor.popups.background }
          }
        }
        opacity: 0.55
      }

      Item {
        id: keys
        width: parent.width
        height: Style.space(24)
        Row {
          visible: root.problem === ""
          spacing: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          KeyCap { anchors.verticalCenter: parent.verticalCenter; keys: "Esc" }
          Text { anchors.verticalCenter: parent.verticalCenter; text: root.armed ? "again to discard your edit" : "cancels"; color: root.armed ? Theme.text : Theme.faint; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Item { width: Style.space(10); height: 1 }
          KeyCap { anchors.verticalCenter: parent.verticalCenter; keys: "Ctrl+Enter" }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "saves"; color: Theme.faint; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
        Text {
          visible: root.problem !== ""
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          elide: Text.ElideRight
          text: root.problem
          color: Theme.red
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  PopupMenu { id: menu; onClosed: editor.forceFocus() }
}
