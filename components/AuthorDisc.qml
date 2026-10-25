import QtQuick
import qs.Commons
import qs.services

// A small disc with the author's initial, coloured by a stable hash of the
// name so one person keeps one colour across documents. "Now" is an
// outlined, empty disc.
Rectangle {
  id: root
  property string who: ""
  property string name: ""
  property real size: Style.space(16)
  readonly property bool now: who === "Now" || who === ""
  readonly property color tone: {
    var palette = [Theme.blue, Theme.green, Theme.yellow, Theme.magenta, Theme.cyan]
    var h = 0, s = name || who
    for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
    return palette[h % palette.length]
  }

  width: size
  height: size
  radius: size / 2
  color: now ? "transparent" : tone
  border.width: now ? Math.max(1, Math.round(size / 10)) : 0
  border.color: Theme.text

  Text {
    anchors.centerIn: parent
    visible: !root.now
    text: root.who.charAt(0).toUpperCase()
    textFormat: Text.PlainText
    color: Theme.bg
    font.family: Style.font.family
    font.pixelSize: Math.round(root.size * 0.6)
    font.bold: true
  }
}
