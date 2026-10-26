import QtQuick
import qs.Commons
import qs.Ui
import qs.services
import qs.components

// The slim bar: file name, its folder dimmed, a "reloaded" pulse after a
// live reload, and the toggles. When the file has earlier versions a
// branching chip opens the version list; while two versions are being
// compared the pill names them ("Now compared with (D) Danny, Fri 23 Oct")
// with the change count and the fold toggle beside it. The reading-progress
// hairline runs along the window's top edge (ReaderWindow).
Rectangle {
  id: root
  property string fileName: ""
  property string folder: ""
  property bool outlineShown: false
  property bool outlineAvailable: true
  property bool wide: false
  property bool findShown: false
  property bool hasDocument: true
  // Changes: the file has versions; the disk differs from the newest one;
  // two versions are being compared; the list is open.
  property bool hasHistory: false
  property bool dirty: false
  property bool comparing: false
  property bool listOpen: false
  property var from: null
  property var to: null
  property int total: 0
  property bool foldOn: false
  signal toggleOutline()
  signal toggleWide()
  signal toggleFind()
  signal copyAll()
  signal showHelp()
  signal toggleVersions()
  signal toggleFold()
  signal stopComparing()

  function pulse() { pulseAnim.restart() }

  // Where the version list hangs: under the pill while comparing, else
  // under the versions chip.
  readonly property real listRight: right.x + (comparing ? pill.x + pill.width : versionsChip.x + versionsChip.width)
  readonly property real listBottom: right.y + right.height

  // A narrow window keeps the file name readable: the pill drops the days
  // and says "vs".
  readonly property bool compact: width < Style.space(1100)

  function dayOf(side) {
    if (!side || !side.when || compact) return ""
    return String(side.when).split(",")[0]
  }

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
      text: ""
      size: Style.font.body
      color: Theme.faint
    }
    Text {
      id: nameLabel
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, Math.max(left.width * 0.55, Math.min(left.width, Style.space(220))))
      elide: Text.ElideMiddle
      text: root.fileName || "OmarkyReader"
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

    // The comparison: both ends, then the count. Click for the list; the
    // cross at the end goes back to plain reading.
    Rectangle {
      id: pill
      visible: root.comparing
      anchors.verticalCenter: parent.verticalCenter
      implicitHeight: Style.space(26)
      implicitWidth: pillRow.implicitWidth + Style.space(22)
      radius: height / 2
      color: pillHover.hovered || root.listOpen ? Theme.hover : "transparent"
      border.width: 1
      border.color: pillHover.hovered || root.listOpen ? Theme.hairline : Theme.hairlineSoft
      Behavior on color { ColorAnimation { duration: Reading.motion(120) } }

      Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: Style.space(6)
        AuthorDisc { visible: !!root.to && root.to.who !== "Now"; who: root.to ? root.to.who || "" : ""; name: root.to ? root.to.name || "" : ""; size: Style.space(15); anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.to ? root.to.label || "" : ""; textFormat: Text.PlainText; font.bold: true; color: Theme.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        Text { visible: !!root.to && root.to.who !== "Now"; text: root.dayOf(root.to); textFormat: Text.PlainText; color: Theme.dim; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.compact ? "vs" : "compared with"; textFormat: Text.PlainText; color: Theme.dim; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        AuthorDisc { who: root.from ? root.from.who || "" : ""; name: root.from ? root.from.name || "" : ""; size: Style.space(15); anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.from ? root.from.label || "" : ""; textFormat: Text.PlainText; font.bold: true; color: Theme.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        Text { visible: text !== ""; text: root.dayOf(root.from); textFormat: Text.PlainText; color: Theme.dim; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        Glyph { text: root.listOpen ? "" : ""; size: Style.font.caption; color: Theme.faint; anchors.verticalCenter: parent.verticalCenter }
        Item {
          width: Style.space(16)
          height: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter
          Glyph { anchors.centerIn: parent; text: ""; size: Style.font.bodySmall; color: closeHover.hovered ? Theme.text : Theme.faint }
          HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: root.stopComparing() }
          PanelToolTip { visible: closeHover.hovered; text: "Back to reading  Esc" }
        }
      }
      HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.toggleVersions() }
    }

    Text {
      visible: root.comparing
      anchors.verticalCenter: parent.verticalCenter
      leftPadding: Style.space(6)
      rightPadding: Style.space(6)
      text: root.total === 0 ? "no changes" : root.total === 1 ? "1 change" : root.total + " changes"
      textFormat: Text.PlainText
      color: Theme.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.features: { "tnum": 1 }
    }

    ChipButton { icon: ""; size: Style.font.body; active: root.findShown; onClicked: root.toggleFind(); tip: "Find  Ctrl+F" }
    ChipButton { icon: ""; size: Style.font.body; onClicked: root.copyAll(); tip: "Copy all  Ctrl+Shift+A" }
    ChipButton { visible: root.comparing && root.total > 0; icon: ""; size: Style.font.body; active: root.foldOn; onClicked: root.toggleFold(); tip: root.foldOn ? "Show everything  F" : "Only what changed  F" }
    ChipButton { visible: root.hasDocument; icon: root.wide ? "" : ""; size: Style.font.body; active: root.wide; onClicked: root.toggleWide(); tip: root.wide ? "Reading width  W" : "Wide width  W" }
    ChipButton { visible: root.hasDocument && root.outlineAvailable; icon: ""; size: Style.font.body; active: root.outlineShown; onClicked: root.toggleOutline(); tip: "Outline  O" }
    Item {
      id: versionsChip
      visible: root.hasDocument && root.hasHistory
      width: versionsButton.width
      height: versionsButton.height
      anchors.verticalCenter: parent.verticalCenter
      ChipButton {
        id: versionsButton
        icon: ""
        size: Style.font.body
        active: root.listOpen || root.comparing
        onClicked: root.toggleVersions()
        tip: root.comparing ? "Choose the versions  V" : root.dirty ? "Changed since the last check-in. Compare  V" : "Compare with an earlier version  V"
      }
      // Work not yet checked in: a small dot on the chip.
      Rectangle {
        visible: root.dirty && !root.comparing
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Style.space(3)
        anchors.topMargin: Style.space(3)
        width: Style.space(6)
        height: width
        radius: width / 2
        color: Theme.accent
      }
    }
    ChipButton { icon: ""; size: Style.font.body; onClicked: root.showHelp(); tip: "Shortcuts  ?" }
  }
}
