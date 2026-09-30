import QtQuick
import Quickshell
import qs.Commons
import qs.services

// No file yet: a calm invitation, Ctrl+O, and the recent files.
Item {
  id: root
  property var recent: []
  property string problem: ""
  signal openRequested()
  signal openPath(string path)

  Column {
    id: column
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.max(Style.space(40), (parent.height - height) * 0.38)
    width: Math.min(parent.width - Style.space(48), Style.space(460))
    spacing: Style.space(14)

    Image {
      anchors.horizontalCenter: parent.horizontalCenter
      source: "../ops/omaread.svg"
      sourceSize.width: Style.space(64)
      sourceSize.height: Style.space(64)
      opacity: 0.9
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.problem || "Open a Markdown file"
      color: root.problem ? Theme.dim : Theme.text
      font.family: Reading.prose
      font.styleName: "Regular"
      font.pixelSize: Reading.size(1)
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(8)
      KeyCap { keys: "Ctrl+O"; anchors.verticalCenter: parent.verticalCenter }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "or drop a file on this window"
        color: Theme.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Item { width: 1; height: Style.space(14); visible: root.recent.length > 0 }

    Text {
      visible: root.recent.length > 0
      text: "Recent"
      color: Theme.faint
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
      font.capitalization: Font.AllUppercase
    }

    Column {
      width: parent.width
      spacing: 0
      Repeater {
        model: root.recent.slice(0, 10)
        Rectangle {
          id: entry
          required property var modelData
          readonly property string name: modelData.split("/").pop()
          readonly property string folder: {
            var d = modelData.slice(0, modelData.lastIndexOf("/"))
            var home = Quickshell.env("HOME")
            return d.indexOf(home) === 0 ? "~" + d.slice(home.length) : d
          }
          width: parent.width
          height: Style.space(32)
          radius: Math.max(3, Style.cornerRadius - 2)
          color: hover.hovered ? Theme.hover : "transparent"
          Behavior on color { ColorAnimation { duration: Reading.motion(120) } }
          Row {
            x: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)
            Glyph { text: ""; size: Style.font.bodySmall; color: Theme.faint; anchors.verticalCenter: parent.verticalCenter }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: entry.name
              color: Theme.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(0, entry.width - x - Style.space(20))
              elide: Text.ElideLeft
              text: entry.folder
              color: Theme.faint
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
          HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: root.openPath(entry.modelData) }
        }
      }
    }
  }
}
