import QtQuick
import qs.Commons
import qs.services

// The slim bar: file name, its folder dimmed, a "reloaded" pulse after a
// live reload, and the toggles. The reading-progress hairline runs along
// the window's top edge (ReaderWindow).
Rectangle {
  id: root
  property string fileName: ""
  property string folder: ""
  property bool outlineShown: false
  property bool outlineAvailable: true
  property bool wide: false
  property bool findShown: false
  signal toggleOutline()
  signal toggleWide()
  signal toggleFind()
  signal copyAll()
  signal showHelp()

  function pulse() { pulseAnim.restart() }

  implicitHeight: Style.space(40)
  color: Theme.bg

  Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hairlineSoft }

  Row {
    id: left
    anchors.left: parent.left
    anchors.leftMargin: Style.space(16)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)
    width: parent.width - right.width - Style.space(48)

    Glyph {
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      size: Style.font.body
      color: Theme.faint
    }
    Text {
      id: nameLabel
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, left.width * 0.55)
      elide: Text.ElideMiddle
      text: root.fileName || "OmaRead"
      textFormat: Text.PlainText
      color: Theme.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, Math.min(implicitWidth, left.width - nameLabel.width - pulseRow.width - Style.space(40)))
      elide: Text.ElideLeft
      text: root.folder
      textFormat: Text.PlainText
      color: Theme.faint
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    Row {
      id: pulseRow
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(5)
      opacity: 0
      Rectangle { width: Style.space(6); height: width; radius: width / 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
      Text {
        text: "reloaded"
        color: Theme.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
      SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: pulseRow; property: "opacity"; to: 1; duration: Reading.motion(120) }
        PauseAnimation { duration: 1100 }
        NumberAnimation { target: pulseRow; property: "opacity"; to: 0; duration: Reading.motion(500) }
      }
    }
  }

  Row {
    id: right
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    ChipButton { icon: ""; size: Style.font.body; active: root.findShown; onClicked: root.toggleFind(); tip: "Find  Ctrl+F" }
    ChipButton { icon: ""; size: Style.font.body; onClicked: root.copyAll(); tip: "Copy all  Ctrl+Shift+A" }
    ChipButton { icon: root.wide ? "" : ""; size: Style.font.body; active: root.wide; onClicked: root.toggleWide(); tip: root.wide ? "Reading width  W" : "Wide width  W" }
    ChipButton { visible: root.outlineAvailable; icon: ""; size: Style.font.body; active: root.outlineShown; onClicked: root.toggleOutline(); tip: "Outline  Ctrl+\\" }
    ChipButton { icon: ""; size: Style.font.body; onClicked: root.showHelp(); tip: "Shortcuts  ?" }
  }
}
