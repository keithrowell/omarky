import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components as OmaRead

// Ctrl+/: every key on one quiet card over a scrim.
Rectangle {
  id: root
  signal closeRequested()
  color: Util.alpha(Theme.bg, 0.72)

  readonly property var groups: [
    { title: "Write", keys: [["Ctrl+B  Ctrl+I", "Bold, italic"], ["Ctrl+E", "Inline code"], ["Ctrl+Shift+X", "Strikethrough"],
                             ["Ctrl+K", "Link"], ["Ctrl+1 … Ctrl+6", "Heading level"], ["Ctrl+0", "Plain paragraph"],
                             ["Tab  Shift+Tab", "Indent, outdent a list item"], ["Enter", "Continue a list or quote"]] },
    { title: "View", keys: [["Ctrl+P", "Preview"], ["Ctrl+Shift+F", "Focus on the paragraph"], ["Ctrl+Shift+T", "Typewriter scrolling"],
                            ["Ctrl+Shift+M", "Next font"], ["Ctrl+Shift+L", "Spelling"], ["Ctrl+=  Ctrl+−", "Text size"]] },
    { title: "File", keys: [["Ctrl+S", "Save (saving is automatic)"], ["Ctrl+Shift+S", "Save as"], ["Ctrl+N", "New window"],
                            ["Ctrl+O", "Open"], ["Ctrl+R", "Recent files and drafts"], ["Ctrl+F  F3", "Find, next match"], ["Ctrl+W", "Close"]] }
  ]

  property string version: ""
  FileView {
    path: Quickshell.shellDir + "/../VERSION"
    printErrors: false
    onLoaded: root.version = text().trim()
  }

  MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(48), Style.space(560))
    height: column.implicitHeight + Style.space(44)
    radius: Math.max(6, Style.cornerRadius)
    color: Color.popups.background
    border.width: 1
    border.color: Theme.hairline
    MouseArea { anchors.fill: parent }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(24)
      y: Style.space(22)
      text: "OmaWriter " + root.version
      color: Theme.ghost
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Column {
      id: column
      x: Style.space(24)
      y: Style.space(22)
      width: parent.width - Style.space(48)
      spacing: Style.space(18)
      Repeater {
        model: root.groups
        delegate: Column {
          required property var modelData
          width: column.width
          spacing: Style.space(7)
          Text {
            text: modelData.title.toUpperCase()
            color: Theme.faint
            font.family: Reading.mono
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }
          Repeater {
            model: modelData.keys
            delegate: Item {
              required property var modelData
              width: column.width
              height: Style.space(26)
              OmaRead.KeyCap { keys: modelData[0]; anchors.verticalCenter: parent.verticalCenter }
              Text {
                x: Style.space(170)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData[1]
                color: Theme.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }
    }
  }
}
