import QtQuick
import qs.Commons
import qs.services

// The list that drops from the version pill: shortcut chips, then every
// check-in of the file as a person, a time and the message. Resting on a
// row opens a card with the whole message. Clicking a row picks it.
Rectangle {
  id: root
  property var history: []
  property var shortcuts: []
  property string currentSha: ""
  // "from": the next pick sets what Now is compared with. "to": the next
  // pick sets the other end (Compare two past versions…).
  property string picking: "from"
  signal pick(string spec)
  signal pickTwo()
  signal closeRequested()

  readonly property real rowH: Style.space(46)
  property int hoverRow: -1

  implicitWidth: Style.space(600)
  implicitHeight: body.implicitHeight + Style.space(16)
  radius: Math.max(6, Style.cornerRadius)
  color: Color.popups.background
  border.width: 1
  border.color: Theme.hairline

  function sectionLabel(text) { return text }

  MouseArea { anchors.fill: parent; hoverEnabled: true; onExited: root.hoverRow = -1 }

  Column {
    id: body
    x: Style.space(8)
    y: Style.space(8)
    width: parent.width - Style.space(16)

    Text {
      leftPadding: Style.space(10); topPadding: Style.space(8); bottomPadding: Style.space(6)
      text: root.picking === "to" ? "Compare which version" : "Compare now with"
      textFormat: Text.PlainText
      color: Theme.ghost
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1.2
      font.capitalization: Font.AllUppercase
    }

    Flow {
      width: parent.width
      leftPadding: Style.space(10); rightPadding: Style.space(10); bottomPadding: Style.space(8)
      spacing: Style.space(6)
      visible: root.picking === "from"
      Repeater {
        model: root.shortcuts
        Rectangle {
          required property var modelData
          implicitHeight: Style.space(24)
          implicitWidth: chipLabel.implicitWidth + Style.space(20)
          radius: height / 2
          color: chipHover.hovered ? Theme.hover : "transparent"
          border.width: 1
          border.color: Theme.hairline
          Text {
            id: chipLabel
            anchors.centerIn: parent
            text: modelData.label
            textFormat: Text.PlainText
            color: chipHover.hovered ? Theme.text : Theme.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: root.pick(modelData.spec) }
        }
      }
    }

    Text {
      leftPadding: Style.space(10); topPadding: Style.space(6); bottomPadding: Style.space(4)
      text: "History"
      textFormat: Text.PlainText
      color: Theme.ghost
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1.2
      font.capitalization: Font.AllUppercase
    }

    ListView {
      id: list
      width: parent.width
      height: Math.min(count, 7) * root.rowH
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: root.history
      delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool current: modelData.sha === root.currentSha
        width: list.width
        height: root.rowH

        Rectangle {
          anchors.fill: parent
          radius: Math.max(4, Style.cornerRadius - 2)
          color: rowHover.hovered ? Theme.hover : row.current ? Util.alpha(Theme.fg, Theme.light ? 0.08 : 0.07) : "transparent"
          Behavior on color { ColorAnimation { duration: Reading.motion(100) } }
        }
        AuthorDisc {
          id: disc
          x: Style.space(10)
          y: Style.space(8)
          who: row.modelData.who || ""
          name: row.modelData.name || ""
        }
        Text {
          id: whoLabel
          anchors.left: disc.right
          anchors.leftMargin: Style.space(10)
          y: Style.space(6)
          text: row.modelData.who || ""
          textFormat: Text.PlainText
          color: Theme.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: row.current
        }
        Text {
          anchors.left: whoLabel.right
          anchors.leftMargin: Style.space(10)
          anchors.baseline: whoLabel.baseline
          text: row.modelData.when || ""
          textFormat: Text.PlainText
          color: Theme.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          anchors.left: whoLabel.left
          anchors.right: parent.right
          anchors.rightMargin: Style.space(12)
          anchors.top: whoLabel.bottom
          anchors.topMargin: Style.space(1)
          text: row.modelData.subject || ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: row.current ? Theme.text : Theme.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        HoverHandler {
          id: rowHover
          cursorShape: Qt.PointingHandCursor
          onHoveredChanged: {
            if (hovered) { root.hoverRow = -1; hoverTimer.restart() }
            else { hoverTimer.stop(); if (root.hoverRow === row.index) root.hoverRow = -1 }
          }
        }
        Timer { id: hoverTimer; interval: 400; onTriggered: root.hoverRow = row.index }
        TapHandler { onTapped: root.pick(row.modelData.sha) }
      }
    }

    Rectangle { width: parent.width; height: 1; color: Theme.hairlineSoft }

    Item {
      width: parent.width
      height: Style.space(34)
      Text {
        x: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: root.picking === "to" ? "Pick the later version, then the earlier one." : root.history.length + (root.history.length === 1 ? " version" : " versions")
        textFormat: Text.PlainText
        color: Theme.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      ChipButton {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.picking === "from" && root.history.length > 1
        label: "Compare two past versions…"
        size: Style.font.caption
        onClicked: root.pickTwo()
      }
    }
  }

  // The whole message for the row under the pointer.
  Rectangle {
    id: card
    visible: root.hoverRow >= 0 && !!root.history[root.hoverRow]
    readonly property var v: root.hoverRow >= 0 ? root.history[root.hoverRow] : null
    readonly property var rowItem: root.hoverRow >= 0 ? list.itemAtIndex(root.hoverRow) : null
    x: body.x + Style.space(10)
    y: rowItem ? body.y + list.y + rowItem.y - list.contentY + rowItem.height + Style.space(2) : 0
    width: body.width - Style.space(20)
    height: cardColumn.implicitHeight + Style.space(24)
    z: 5
    radius: Math.max(6, Style.cornerRadius)
    color: Theme.bg
    border.width: 1
    border.color: Theme.hairline

    Column {
      id: cardColumn
      x: Style.space(14)
      y: Style.space(12)
      width: parent.width - Style.space(28)
      spacing: Style.space(6)
      Text {
        width: parent.width
        text: card.v ? card.v.subject || "" : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Theme.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      Text {
        width: parent.width
        visible: text !== ""
        text: card.v ? card.v.body || "" : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Theme.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        lineHeight: 1.3
      }
      Text {
        width: parent.width
        text: card.v ? (card.v.name || "") + ", " + (card.v.long || "") : ""
        textFormat: Text.PlainText
        color: Theme.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
