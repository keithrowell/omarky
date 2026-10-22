import QtQuick
import QtTest
import OmaWriter.Native

// native/: the highlighter on a live TextEdit. Typing, undo and the hanging
// layout it sets (heading and list marks sit left of the text column).
TestCase {
  id: tc
  name: "Highlighter"
  when: windowShown
  width: 900
  height: 600

  TextEdit {
    id: edit
    width: 800
    textFormat: TextEdit.PlainText
    wrapMode: TextEdit.Wrap
    font.family: "iA Writer Duospace"
    font.pixelSize: 18
    focus: true
  }

  MarkdownHighlighter {
    id: hl
    document: edit.textDocument
    cursorPosition: edit.cursorPosition
    look: ({ prose: "iA Writer Duospace", mono: "iA Writer Mono S", size: 18, lineHeight: 150, gutter: 60 })
  }

  function settle() { wait(30) }

  function test_load_sets_gutter_and_hang() {
    edit.text = "Plain\n## Heading\n- item"
    settle()
    var plain = edit.positionToRectangle(0).x
    var heading = edit.positionToRectangle(6).x
    var item = edit.positionToRectangle(17).x
    fuzzyCompare(plain, 60, 1)
    verify(heading < 60, "heading mark hangs: " + heading)
    verify(item < 60, "list marker hangs: " + item)
    // The text after a mark lines up with plain text.
    fuzzyCompare(edit.positionToRectangle(9).x, 60, 2)
    fuzzyCompare(edit.positionToRectangle(19).x, 60, 2)
    verify(!edit.canUndo, "a load leaves nothing to undo")
  }

  function test_typing_a_list_then_undo() {
    edit.text = ""
    settle()
    edit.forceActiveFocus()
    keyClick(Qt.Key_Minus)
    keyClick(Qt.Key_Space)
    keyClick(Qt.Key_A)
    settle()
    verify(edit.positionToRectangle(0).x < 60, "typed marker hangs")
    // Undo steps back through the typing (the marker becoming a list
    // closes one step) and takes the hang with it.
    var guard = 0
    while (edit.canUndo && guard++ < 10) { edit.undo(); settle() }
    compare(edit.text, "")
    fuzzyCompare(edit.positionToRectangle(0).x, 60, 1)
    guard = 0
    while (edit.canRedo && guard++ < 10) { edit.redo(); settle() }
    compare(edit.text, "- a")
    verify(edit.positionToRectangle(0).x < 60, "hang is back after redo")
  }

  function test_fence_lines_dont_hang() {
    edit.text = "```\n- not a list\n```"
    settle()
    fuzzyCompare(edit.positionToRectangle(4).x, 60, 1)
  }

  function test_spelling() {
    verify(hl.spellAvailable)
    verify(!hl.isCorrect("recieve"))
    verify(hl.isCorrect("colour"))
    verify(hl.suggestions("recieve").indexOf("receive") >= 0)
  }

  function test_paragraph_at() {
    edit.text = "one\ntwo\n\nthree"
    settle()
    var p = hl.paragraphAt(5)
    compare(p.start, 0)
    compare(p.end, 7)
  }
}
