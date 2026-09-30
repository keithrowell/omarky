import QtQuick
import qs.services

// Raw HTML, shown as the source it is (never interpreted): muted mono,
// stepped in behind a faint rule.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})
  implicitHeight: source.implicitHeight

  Rectangle { width: 1; height: parent.height; color: Theme.hairline }

  TextEdit {
    id: source
    x: Math.round(Reading.body * 0.9)
    width: parent.width - x
    readOnly: true
    selectByMouse: true
    activeFocusOnPress: false
    textFormat: TextEdit.PlainText
    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
    text: root.block.text
    color: Theme.faint
    selectionColor: Theme.selection
    selectedTextColor: Theme.text
    font.family: Reading.mono
    font.pixelSize: Math.round(Reading.body * 0.8)
  }
}
