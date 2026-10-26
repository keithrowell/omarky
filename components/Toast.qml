import QtQuick
import qs.Commons
import qs.services

// A brief confirmation at the bottom of the window ("Copied …").
Rectangle {
  id: root
  property string message: ""

  function show(text) {
    message = text
    shown = true
    hideTimer.restart()
  }
  property bool shown: false

  anchors.horizontalCenter: parent.horizontalCenter
  y: parent.height - height - Style.space(28) + (shown ? 0 : Style.space(8))
  width: label.implicitWidth + Style.space(28)
  height: label.implicitHeight + Style.space(14)
  radius: height / 2
  color: ShellColor.popups.background
  border.width: 1
  border.color: Theme.hairline
  opacity: shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Reading.motion(140) } }
  Behavior on y { NumberAnimation { duration: Reading.motion(160); easing.type: Easing.OutCubic } }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.message
    textFormat: Text.PlainText
    color: Theme.text
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  Timer { id: hideTimer; interval: 1600; onTriggered: root.shown = false }
}
