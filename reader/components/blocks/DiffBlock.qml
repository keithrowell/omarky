import QtQuick
import qs.Commons
import qs.services
import qs.components
import "../../lib/code.js" as Code

// The Factory DiffView look, refined: a header with +N −M, then each line
// on a full-width band (green added, red removed, ~14%), a +/− gutter, and
// hunk headers in blue. Long lines scroll sideways like code.
Rectangle {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property real size: Reading.codeSize
  readonly property real lineH: Math.round(size * Reading.codeLeading)
  readonly property real padX: Math.round(Reading.body * 1.1)
  readonly property real padY: Math.round(Reading.body * 0.7)
  readonly property real headerH: Math.round(Reading.body * 2.1)
  readonly property real signW: Math.round(size * 1.6)
  property bool copied: false

  implicitHeight: headerH + 1 + padY * 2 + block.lines.length * lineH
  radius: Math.max(4, Style.cornerRadius)
  color: Theme.panel
  border.width: 1
  border.color: Theme.hairlineSoft
  clip: true

  function tone(kind) {
    return kind === "add" ? Theme.green : kind === "del" ? Theme.red : kind === "hunk" ? Theme.blue : Theme.faint
  }

  function linesHtml() {
    var out = ""
    for (var i = 0; i < block.lines.length; i++) {
      var l = block.lines[i]
      var c = l.kind === "add" ? Theme.mix(Theme.text, Theme.green, 0.3)
            : l.kind === "del" ? Theme.mix(Theme.text, Theme.red, 0.3)
            : l.kind === "hunk" ? Theme.blue
            : l.kind === "meta" ? Theme.faint : Theme.text
      out += Code.lineHtml(l.text, lineH, "; color:" + Theme.hex(c))
    }
    return out
  }

  function signsHtml() {
    var out = ""
    for (var i = 0; i < block.lines.length; i++) {
      var l = block.lines[i]
      out += Code.lineHtml(l.sign === " " ? "" : l.sign, lineH, "; color:" + Theme.hex(tone(l.kind)))
    }
    return out
  }

  FontMetrics { id: metrics; font.family: Reading.mono; font.pixelSize: root.size }
  HoverHandler { id: hover }

  // ---- header: +N −M, badge / copy
  Row {
    x: root.padX
    height: root.headerH
    spacing: Math.round(Reading.body * 0.6)
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "+" + root.block.added
      color: Theme.green
      font.family: Reading.mono
      font.pixelSize: Reading.chromeSmall
      font.styleName: "Bold"
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "−" + root.block.removed
      color: Theme.red
      font.family: Reading.mono
      font.pixelSize: Reading.chromeSmall
      font.styleName: "Bold"
    }
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: root.padX
    y: Math.round((root.headerH - height) / 2)
    text: root.block.lang.toLowerCase()
    color: Theme.faint
    font.family: Reading.mono
    font.pixelSize: Reading.chromeSmall
    font.letterSpacing: 0.4
    opacity: hover.hovered || root.copied ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Reading.motion(120) } }
  }

  ChipButton {
    anchors.right: parent.right
    anchors.rightMargin: Math.round(root.padX * 0.4)
    y: Math.round((root.headerH - height) / 2)
    icon: root.copied ? "" : ""
    label: root.copied ? "Copied" : "Copy"
    tint: root.copied ? Theme.green : Theme.dim
    color: Theme.panel
    opacity: hover.hovered || root.copied ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Reading.motion(140) } }
    onClicked: {
      if (root.ctx) root.ctx.copyText(root.block.text)
      root.copied = true
      copiedTimer.restart()
    }
  }
  Timer { id: copiedTimer; interval: 1400; onTriggered: root.copied = false }

  Rectangle { y: root.headerH; width: parent.width; height: 1; color: Theme.hairlineSoft }

  // ---- full-width line bands
  Column {
    y: root.headerH + 1 + root.padY
    width: parent.width
    Repeater {
      model: root.block.lines
      Rectangle {
        required property var modelData
        width: parent.width
        height: root.lineH
        color: modelData.kind === "add" ? Util.alpha(Theme.green, 0.14)
             : modelData.kind === "del" ? Util.alpha(Theme.red, 0.14)
             : modelData.kind === "hunk" ? Util.alpha(Theme.blue, 0.07)
             : "transparent"
      }
    }
  }

  TextEdit {
    x: root.padX
    y: root.headerH + 1 + root.padY
    width: root.signW
    readOnly: true
    selectByMouse: false
    activeFocusOnPress: false
    textFormat: TextEdit.RichText
    font.family: Reading.mono
    font.pixelSize: root.size
    text: root.signsHtml()
  }

  Flickable {
    id: flick
    x: root.padX + root.signW
    y: root.headerH + 1 + root.padY
    width: parent.width - x - root.padX
    height: code.implicitHeight
    contentWidth: code.implicitWidth
    contentHeight: height
    interactive: false
    clip: true

    TextEdit {
      id: code
      readOnly: true
      selectByMouse: true
      activeFocusOnPress: false
      textFormat: TextEdit.RichText
      wrapMode: TextEdit.NoWrap
      color: Theme.text
      selectionColor: Theme.selection
      selectedTextColor: Theme.text
      font.family: Reading.mono
      font.pixelSize: root.size
      tabStopDistance: metrics.averageCharacterWidth * 4
      text: root.linesHtml()
    }
  }

  WheelHandler {
    target: null
    enabled: flick.contentWidth > flick.width
    orientation: Qt.Horizontal
    onWheel: event => {
      flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - event.angleDelta.x / 2))
    }
  }
}
