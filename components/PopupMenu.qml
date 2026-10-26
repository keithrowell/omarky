import QtQuick
import qs.Commons
import qs.services

// A small menu at a point: spelling suggestions and edit actions. Items are
// { label, keys?, strong?, disabled?, separator?, run }.
Item {
  id: root
  anchors.fill: parent
  visible: shown
  property bool shown: false
  property var items: []
  property real px: 0
  property real py: 0
  signal closed()

  function open(x, y, list) {
    items = list
    px = x
    py = y
    shown = true
  }
  function close() { shown = false; closed() }

  MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.close() }

  Rectangle {
    id: card
    x: Math.min(root.px, root.width - width - Style.space(8))
    y: Math.min(root.py, root.height - height - Style.space(8))
    width: Math.max(Style.space(200), col.implicitWidth + Style.space(12))
    height: col.implicitHeight + Style.space(12)
    radius: Math.max(6, Style.cornerRadius)
    color: ShellColor.popups.background
    border.width: 1
    border.color: Theme.hairline
    MouseArea { anchors.fill: parent }

    Column {
      id: col
      x: Style.space(6)
      y: Style.space(6)
      width: parent.width - Style.space(12)
      Repeater {
        model: root.items
        delegate: Item {
          id: row
          required property var modelData
          width: col.width
          implicitWidth: label.implicitWidth + keys.implicitWidth + Style.space(40)
          height: modelData.separator ? Style.space(9) : Style.space(30)
          Rectangle {
            visible: !!row.modelData.separator
            anchors.verticalCenter: parent.verticalCenter
            x: Style.space(8); width: parent.width - Style.space(16); height: 1
            color: Theme.hairlineSoft
          }
          Rectangle {
            visible: !row.modelData.separator
            anchors.fill: parent
            radius: Math.max(3, Style.cornerRadius - 2)
            color: hover.hovered && !row.modelData.disabled ? Theme.hover : "transparent"
          }
          Text {
            id: label
            visible: !row.modelData.separator
            anchors.verticalCenter: parent.verticalCenter
            x: Style.space(10)
            text: row.modelData.label || ""
            textFormat: Text.PlainText
            color: row.modelData.disabled ? Theme.faint : (row.modelData.strong ? Theme.strong : Theme.text)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: !!row.modelData.strong
          }
          Text {
            id: keys
            visible: !row.modelData.separator && !!row.modelData.keys
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            text: row.modelData.keys || ""
            color: Theme.faint
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          HoverHandler { id: hover }
          TapHandler {
            enabled: !row.modelData.separator && !row.modelData.disabled
            onTapped: { var run = row.modelData.run; root.close(); if (run) run() }
          }
        }
      }
    }
  }
}
