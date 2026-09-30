import QtQuick
import qs.Commons
import qs.services

// A small quiet button: an icon and optional label, a hairline and a soft
// fill that eases in on hover.
Rectangle {
  id: root
  property string icon: ""
  property string label: ""
  property color tint: Theme.dim
  property real size: Math.round(Reading.chromeSmall)
  property bool active: false
  signal clicked()

  implicitHeight: Math.round(size * 2)
  implicitWidth: row.implicitWidth + Math.round(size * (label ? 1.3 : 1.1))
  radius: Math.max(3, Math.min(Style.cornerRadius, height / 3))
  color: mouse.containsMouse || active ? Theme.hover : "transparent"
  border.width: 1
  border.color: mouse.containsMouse || active ? Theme.hairline : "transparent"
  Behavior on color { ColorAnimation { duration: Reading.motion(120) } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Math.round(root.size * 0.45)
    Glyph { visible: root.icon !== ""; text: root.icon; size: root.size; color: mouse.containsMouse || root.active ? Theme.text : root.tint; anchors.verticalCenter: parent.verticalCenter }
    Text {
      visible: root.label !== ""
      text: root.label
      textFormat: Text.PlainText
      color: mouse.containsMouse || root.active ? Theme.text : root.tint
      font.family: Reading.mono
      font.pixelSize: root.size
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
