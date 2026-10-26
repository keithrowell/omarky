import QtQuick
import qs.Commons
import qs.services

// Ctrl+F: a small card under the header. Typing finds as you go; Enter and
// Shift+Enter step through matches; Esc closes.
Rectangle {
  id: root
  property int count: 0
  property int current: -1
  property alias query: field.text
  signal next()
  signal previous()
  signal closeRequested()

  function focusField() { field.forceActiveFocus(); field.selectAll() }

  implicitWidth: Style.space(380)
  implicitHeight: Style.space(40)
  radius: Math.max(4, Style.cornerRadius)
  color: ShellColor.popups.background
  border.width: 1
  border.color: Theme.hairline

  Glyph {
    id: icon
    x: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    text: ""
    size: Style.font.body
    color: Theme.faint
  }

  TextInput {
    id: field
    anchors.left: icon.right
    anchors.leftMargin: Style.space(8)
    anchors.right: countLabel.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    clip: true
    color: Theme.text
    selectionColor: Theme.selection
    selectedTextColor: Theme.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (event.modifiers & Qt.ShiftModifier) root.previous()
        else root.next()
        event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        root.closeRequested()
        event.accepted = true
      }
    }

    Text {
      visible: field.text === ""
      anchors.verticalCenter: parent.verticalCenter
      text: "Find in document"
      color: Theme.ghost
      font: field.font
    }
  }

  Text {
    id: countLabel
    anchors.right: buttons.left
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    text: field.text === "" ? "" : root.count === 0 ? "No matches" : (root.current + 1) + " / " + root.count
    textFormat: Text.PlainText
    color: root.count === 0 && field.text !== "" ? Theme.red : Theme.faint
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.features: { "tnum": 1 }
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    ChipButton { icon: ""; size: Style.font.body; onClicked: root.previous(); tip: "Previous  Shift+Enter" }
    ChipButton { icon: ""; size: Style.font.body; onClicked: root.next(); tip: "Next  Enter" }
    ChipButton { icon: ""; size: Style.font.body; onClicked: root.closeRequested(); tip: "Close  Esc" }
  }
}
