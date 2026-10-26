import QtQuick
import Omarky.Native

// The native highlighter bound to an Editor. Kept in its own file so the
// import can fail without taking Editor.qml with it: Editor creates this
// only when the module is on QML_IMPORT_PATH.
MarkdownHighlighter {
  required property var edit
  required property Item editor
  document: edit.textDocument
  cursorPosition: edit.cursorPosition
  focusMode: editor.focusMode
  spellCheck: editor.spellCheck
  look: editor.look
}
