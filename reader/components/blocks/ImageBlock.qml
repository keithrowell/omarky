import QtQuick
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components

// An image that fits the column, keeps its aspect ratio, has rounded
// corners and its alt text as a dim caption. Local paths resolve against
// the file; a missing image becomes a small, neat placeholder.
Column {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property string url: ctx ? ctx.resolveUrl(block.src) : block.src
  readonly property bool local: url.indexOf("file://") === 0
  // Local files are checked first: a missing one must not reach Image,
  // which would log a warning.
  property bool found: !local
  property bool checked: !local
  readonly property bool failed: img.status === Image.Error || block.src === "" || (checked && !found)
  readonly property bool ready: img.status === Image.Ready
  spacing: Math.round(Reading.body * 0.6)

  // Natural size, capped by the column; never upscaled.
  readonly property real natW: img.implicitWidth > 0 ? img.implicitWidth : width
  readonly property real shownW: Math.min(natW, width)
  readonly property real shownH: img.implicitWidth > 0 ? Math.round(shownW * img.implicitHeight / img.implicitWidth) : 0

  Item {
    visible: root.ready
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.shownW
    height: root.shownH

    Image {
      id: img
      anchors.fill: parent
      source: root.found ? root.url : ""
      asynchronous: true
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
    }
    CornerMask {
      anchors.fill: parent
      radius: Math.max(4, Style.cornerRadius)
      color: root.look.surface || Theme.bg
    }
  }

  // Loading or missing.
  Rectangle {
    visible: !root.ready
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(root.width, placeholder.implicitWidth + Reading.body * 2.4)
    height: Math.round(Reading.body * 3.4)
    radius: Math.max(4, Style.cornerRadius)
    color: Theme.card
    border.width: 1
    border.color: Theme.hairline

    Row {
      id: placeholder
      anchors.centerIn: parent
      spacing: Math.round(Reading.body * 0.5)
      Text {
        text: root.failed ? "" : ""
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(Reading.body * 1.05)
        color: Theme.faint
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: root.failed ? (root.block.src ? "Image not found · " + root.block.src : "No image") : "Loading image…"
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        width: Math.min(implicitWidth, root.width - Reading.body * 5)
        color: Theme.faint
        font.family: Reading.mono
        font.pixelSize: Math.round(Reading.body * 0.76)
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Process {
    running: root.local
    command: ["test", "-r", decodeURI(root.url.slice(7))]
    onExited: code => { root.found = code === 0; root.checked = true }
  }

  Text {
    visible: root.block.alt !== ""
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    text: root.block.alt
    textFormat: Text.PlainText
    color: Theme.dim
    font.family: Reading.prose
    font.styleName: "Italic"
    font.pixelSize: Math.round(Reading.body * 0.84)
  }
}
