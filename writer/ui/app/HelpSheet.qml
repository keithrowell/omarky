import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components as OmarkyReader

// Ctrl+/: every key on one quiet card over a scrim.
Rectangle {
  id: root
  signal closeRequested()
  color: Util.alpha(Theme.bg, 0.72)

  // Listed only when Claude Code is installed.
  property bool rewrite: false
  readonly property var groups: allGroups.filter(function(g) { return g.title !== "Rewrite with Claude" || root.rewrite })
  readonly property var allGroups: [
    { title: "Write", keys: [["Ctrl+B  Ctrl+I", "Bold, italic"], ["Ctrl+E", "Inline code"], ["Ctrl+Shift+X", "Strikethrough"],
                             ["Ctrl+K", "Link"], ["Ctrl+1 … Ctrl+6", "Heading level"], ["Ctrl+0", "Plain paragraph"],
                             ["Tab  Shift+Tab", "Indent, outdent a list item"], ["Enter", "Continue a list or quote"]] },
    { title: "Rewrite with Claude", keys: [["Ctrl+J", "Rewrite the block or selection"], ["Ctrl+Shift+J", "Rewrite the section"],
                                           ["Ctrl+J again", "Take in more"], ["Enter  Esc", "Use the rewrite, drop it"],
                                           ["Alt+↑  Alt+↓", "Earlier and later rewrites"]] },
    { title: "View", keys: [["Ctrl+P", "Preview"], ["Ctrl+Shift+F", "Focus on the paragraph"], ["Ctrl+Shift+T", "Typewriter scrolling"],
                            ["Ctrl+Shift+M", "Next font"], ["Ctrl+Shift+L", "Spelling"], ["Ctrl+=  Ctrl+−", "Text size"]] },
    { title: "File", keys: [["Ctrl+S", "Save (saving is automatic)"], ["Ctrl+Shift+S", "Save as"], ["Ctrl+N", "New window"],
                            ["Ctrl+O", "Open"], ["Ctrl+R", "Recent files and drafts"], ["Ctrl+F  F3", "Find, next match"], ["Ctrl+W", "Close"]] }
  ]

  property string version: ""
  FileView {
    path: Quickshell.shellDir + "/../../VERSION"
    printErrors: false
    onLoaded: root.version = text().trim()
  }

  MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

  // Two columns of groups when the window is wide enough, one otherwise.
  readonly property bool twoCols: width > Style.space(1040)
  readonly property real colWidth: Style.space(470)
  readonly property int split: twoCols ? Math.ceil(groups.length / 2) : groups.length

  component Group: Column {
    required property var modelData
    width: root.colWidth
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
        width: root.colWidth
        height: Style.space(26)
        OmarkyReader.KeyCap { keys: modelData[0]; anchors.verticalCenter: parent.verticalCenter }
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

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(48), row.implicitWidth + Style.space(48))
    height: row.implicitHeight + Style.space(44)
    radius: Math.max(6, Style.cornerRadius)
    color: ShellColor.popups.background
    border.width: 1
    border.color: Theme.hairline
    MouseArea { anchors.fill: parent }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(24)
      y: Style.space(22)
      text: "OmarkyWriter " + root.version
      color: Theme.ghost
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Row {
      id: row
      x: Style.space(24)
      y: Style.space(22)
      spacing: Style.space(40)
      Column {
        spacing: Style.space(18)
        Repeater { model: root.groups.slice(0, root.split); delegate: Group {} }
      }
      Column {
        visible: root.twoCols
        spacing: Style.space(18)
        Repeater { model: root.groups.slice(root.split); delegate: Group {} }
      }
    }
  }
}
