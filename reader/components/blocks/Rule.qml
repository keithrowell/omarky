import QtQuick
import qs.services

// A section break: three small dots, centred. Never a full-width line.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})
  implicitHeight: Math.round(Reading.body * 1.2)

  Row {
    anchors.centerIn: parent
    spacing: Math.round(Reading.body * 0.9)
    Repeater {
      model: 3
      Rectangle {
        width: Math.max(3, Math.round(Reading.body * 0.22))
        height: width
        radius: width / 2
        color: Theme.faint
      }
    }
  }
}
