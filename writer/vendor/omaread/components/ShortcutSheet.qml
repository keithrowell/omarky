import QtQuick
import Quickshell.Io
import qs.Commons
import qs.services

// `?`: every key on one quiet card over a scrim. Any of ?, q or Esc closes.
Rectangle {
  id: root
  signal closeRequested()
  color: Util.alpha(Theme.bg, 0.72)

  readonly property var groups: [
    { title: "Read", keys: [["j  k  ↓  ↑", "Scroll"], ["Space  Shift+Space", "Page down / up"], ["g g  G", "Top / bottom"],
                            ["Ctrl+\\", "Outline"], ["W", "Reading / wide measure"], ["Ctrl+  Ctrl−  Ctrl+0", "Zoom text"]] },
    { title: "Find & copy", keys: [["Ctrl+F", "Find"], ["Enter  Shift+Enter", "Next / previous match"],
                                   ["Right-click", "Copy a block's Markdown"], ["Ctrl+Shift+C", "Copy the block under the mouse"],
                                   ["Ctrl+Shift+A", "Copy the whole file"]] },
    { title: "File", keys: [["Ctrl+O", "Open a file"], ["Ctrl+R", "Reload"], ["Ctrl+W  q", "Close window"], ["?", "This sheet"]] }
  ]

  property string version: ""
  FileView {
    path: Qt.resolvedUrl("../VERSION").toString().replace("file://", "")
    printErrors: false
    onLoaded: root.version = text().trim()
  }

  MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(48), Style.space(520))
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
      text: "OmaRead " + root.version
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
        Column {
          required property var modelData
          width: column.width
          spacing: Style.space(8)
          Text {
            text: modelData.title
            color: Theme.faint
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
            font.capitalization: Font.AllUppercase
          }
          Repeater {
            model: modelData.keys
            Item {
              required property var modelData
              width: column.width
              height: Style.space(24)
              KeyCap { anchors.verticalCenter: parent.verticalCenter; keys: modelData[0] }
              Text {
                x: Style.space(190)
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
