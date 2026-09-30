import QtQuick
import qs.Commons
import qs.services
import qs.components
import "../../lib/code.js" as Code

// A sunken panel: hairline border, language badge top-right, a copy button
// on hover, line numbers past eight lines. Highlighted with KSH when it is
// installed; long lines scroll sideways inside the panel, never wrap.
Rectangle {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property real size: Reading.codeSize
  readonly property real lineH: Math.round(size * Reading.codeLeading)
  readonly property real padX: Math.round(Reading.body * 1.1)
  readonly property real padY: Math.round(Reading.body * 0.85)
  // The top band is a little taller: the language badge sits in it, clear
  // of the first line.
  readonly property real padTop: Math.round(Reading.body * 1.25)
  readonly property bool numbered: block.lineCount > 8
  readonly property real gutterW: numbered ? Math.ceil(metrics.advanceWidth(String(block.lineCount))) + Math.round(size * 1.4) : 0
  property bool copied: false

  // Find (see RichText.qml): this block is one searchable piece.
  readonly property var finder: ctx ? ctx.finder : null
  readonly property string findQuery: finder && block.pid !== undefined ? finder.query : ""
  readonly property int currentK: finder && finder.currentPid === block.pid ? finder.currentK : -1
  readonly property var findOpts: findQuery ? { find: findQuery, findBg: Reading.tones.findBg, current: currentK,
                                                currentBg: Reading.tones.currentBg, currentText: Reading.tones.currentText } : null

  function revealCurrent() {
    if (currentK < 0 || !ctx) return
    var line = Code.lineOfMatch(block.text, findQuery, currentK)
    if (line < 0) return
    ctx.revealMatch(root, padTop + line * lineH + lineH / 2)
    // Scroll sideways to a match past the right edge of a long line.
    var r = code.positionToRectangle(Code.docPosOfMatch(block.text, findQuery, currentK))
    if (r.x < flick.contentX || r.x > flick.contentX + flick.width - Reading.body * 3)
      flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, r.x - flick.width / 3))
  }
  onCurrentKChanged: if (currentK >= 0) Qt.callLater(revealCurrent)
  Component.onCompleted: if (currentK >= 0) Qt.callLater(revealCurrent)

  implicitHeight: Math.max(code.implicitHeight, lineH) + padTop + padY
  radius: Math.max(4, Style.cornerRadius)
  color: Theme.panel
  border.width: 1
  border.color: Theme.hairlineSoft
  clip: true

  FontMetrics { id: metrics; font.family: Reading.mono; font.pixelSize: root.size }

  HoverHandler { id: hover }

  // Line numbers, fixed while the code scrolls.
  TextEdit {
    id: gutter
    visible: root.numbered
    x: root.padX
    y: root.padTop
    width: root.gutterW - Math.round(root.size * 1.4)
    readOnly: true
    selectByMouse: false
    activeFocusOnPress: false
    textFormat: TextEdit.RichText
    color: Theme.ghost
    font.family: Reading.mono
    font.pixelSize: root.size
    font.features: { "tnum": 1 }
    text: root.numbered ? Code.gutter(root.block.lineCount, root.lineH) : ""
  }

  Flickable {
    id: flick
    x: root.padX + root.gutterW
    y: root.padTop
    width: parent.width - x - root.padX
    height: code.implicitHeight
    contentWidth: code.implicitWidth
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
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
      text: Code.toHtml(root.block.text, root.lineH, root.findOpts)
      onSelectedTextChanged: if (selectedText && root.ctx) root.ctx.claimSelection(code)
    }
  }

  // Shift+wheel and sideways swipes scroll long lines.
  WheelHandler {
    target: null
    enabled: flick.contentWidth > flick.width
    orientation: Qt.Horizontal
    onWheel: event => {
      var d = event.angleDelta.x !== 0 ? event.angleDelta.x : 0
      flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - d / 2))
    }
  }

  // Fade the right edge while there is more to the right.
  Rectangle {
    visible: flick.contentWidth > flick.width + 1 && flick.contentX < flick.contentWidth - flick.width - 1
    x: parent.width - root.padX - width
    y: 1
    width: Math.round(Reading.body * 2.4)
    height: parent.height - 2
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Util.alpha(Theme.panel, 0) }
      GradientStop { position: 1; color: Theme.panel }
    }
  }

  Loader {
    active: Highlight.ready && Highlight.moduleAvailable && root.block.lang !== ""
    source: "../CodeHighlighter.qml"
    onLoaded: { item.target = code; item.lang = root.block.lang }
  }

  // Badge, top right; the copy button takes its place on hover.
  Item {
    anchors.right: parent.right
    anchors.rightMargin: Math.round(root.padX * 0.4)
    y: Math.max(2, Math.round((root.padTop - height) / 2) - 1)
    width: copy.width
    height: copy.height

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Math.round(root.padX * 0.5)
      anchors.verticalCenter: parent.verticalCenter
      visible: root.block.lang !== ""
      text: root.block.lang.toLowerCase()
      textFormat: Text.PlainText
      color: Theme.faint
      font.family: Reading.mono
      font.pixelSize: Reading.chromeSmall
      font.letterSpacing: 0.4
      opacity: hover.hovered || root.copied ? 0 : 1
      Behavior on opacity { NumberAnimation { duration: Reading.motion(120) } }
    }

    ChipButton {
      id: copy
      anchors.right: parent.right
      icon: root.copied ? "\uf42e" : "\uf4bb"
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
  }

  Timer { id: copiedTimer; interval: 1400; onTriggered: root.copied = false }
}
