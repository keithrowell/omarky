import QtQuick
import qs.Commons
import qs.services
import qs.components

// YAML front matter as a card: the title first, then key → value rows.
// Short values are pills (statuses coloured by meaning, dates with a
// calendar), lists are chips, links are links, long values wrap.
Rectangle {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})

  readonly property real pad: Math.round(Reading.body * 1.2)
  readonly property real keySize: Math.round(Reading.body * 0.74)
  readonly property real rowGap: Math.round(Reading.body * 0.55)
  readonly property real keyW: {
    var w = 0
    for (var i = 0; i < block.fields.length; i++) w = Math.max(w, keyMetrics.advanceWidth(block.fields[i].key.toUpperCase()))
    return Math.ceil(Math.min(w, Reading.body * 9)) + Math.round(Reading.body * 1.2)
  }

  function statusTone(v) {
    var s = String(v).toLowerCase()
    if (/accept|approv|done|complete|shipped|merged|final|publish|active|ready|resolved|live/.test(s)) return Theme.green
    if (/draft|propos|wip|progress|pending|review|open|todo|planned|exploring/.test(s)) return Theme.yellow
    if (/reject|deprecat|supersed|block|abandon|closed|cancel|obsolete|failed/.test(s)) return Theme.red
    return "transparent"
  }
  function isDate(v) { return /^\d{4}-\d{2}-\d{2}([ T].*)?$/.test(String(v)) }

  implicitHeight: column.implicitHeight + pad * 2
  radius: Math.max(6, Style.cornerRadius)
  color: Theme.card
  border.width: 1
  border.color: Theme.hairline

  FontMetrics { id: keyMetrics; font.family: Reading.mono; font.pixelSize: root.keySize; font.letterSpacing: 0.8 }

  Text {
    id: label
    anchors.right: parent.right
    anchors.rightMargin: root.pad
    y: root.pad - Math.round(Reading.body * 0.35)
    text: "front matter"
    textFormat: Text.PlainText
    color: Theme.ghost
    font.family: Reading.mono
    font.pixelSize: Math.round(Reading.body * 0.66)
    font.letterSpacing: 0.8
    font.capitalization: Font.AllUppercase
  }

  Column {
    id: column
    x: root.pad
    y: root.pad
    width: parent.width - root.pad * 2
    spacing: root.rowGap

    RichText {
      visible: root.block.title !== ""
      width: parent.width - label.width - Reading.body
      runs: [{ t: root.block.title }]
      size: Reading.size(1.5)
      leading: 1.3
      family: Reading.heading
      styleName: Reading.headingStyle
      baseColor: Theme.strong
      bottomPadding: Math.round(Reading.body * 0.6)
    }

    Repeater {
      model: root.block.fields

      Row {
        id: fieldRow
        required property var modelData
        width: column.width
        spacing: 0

        Item {
          width: root.keyW
          height: Math.round(Reading.body * 1.55)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Reading.body
            elide: Text.ElideRight
            text: fieldRow.modelData.key
            textFormat: Text.PlainText
            color: Theme.faint
            font.family: Reading.mono
            font.pixelSize: root.keySize
            font.letterSpacing: 0.8
            font.capitalization: Font.AllUppercase
          }
        }

        Loader {
          width: column.width - root.keyW
          sourceComponent: fieldRow.modelData.kind === "list" ? listValue
                         : fieldRow.modelData.kind === "pill" ? pillValue
                         : fieldRow.modelData.kind === "link" ? linkValue
                         : fieldRow.modelData.kind === "empty" ? emptyValue : textValue
          property var field: fieldRow.modelData
        }
      }
    }
  }

  Component {
    id: pillValue
    Item {
      property var field: parent && parent.field ? parent.field : ({ key: "", value: "", items: [] })
      height: Math.round(Reading.body * 1.55)
      Pill {
        anchors.verticalCenter: parent.verticalCenter
        text: field.value
        icon: root.isDate(field.value) ? "" : ""
        tone: field.key.toLowerCase() === "status" || field.key.toLowerCase() === "state" ? root.statusTone(field.value) : "transparent"
      }
    }
  }

  Component {
    id: listValue
    Flow {
      property var field: parent && parent.field ? parent.field : ({ key: "", value: "", items: [] })
      spacing: Math.round(Reading.body * 0.35)
      topPadding: Math.round((Reading.body * 1.55 - Reading.body * 0.76 * 2) / 2)
      Repeater {
        model: field.items
        Pill { required property var modelData; text: modelData }
      }
    }
  }

  Component {
    id: linkValue
    Item {
      property var field: parent && parent.field ? parent.field : ({ key: "", value: "", items: [] })
      height: Math.round(Reading.body * 1.55)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width)
        elide: Text.ElideMiddle
        text: field.value
        textFormat: Text.PlainText
        color: Theme.link
        font.family: Reading.prose
        font.styleName: "Regular"
        font.pixelSize: Math.round(Reading.body * 0.9)
        font.underline: linkHover.hovered
        HoverHandler { id: linkHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (root.ctx) root.ctx.openLink(field.value) }
      }
    }
  }

  // A key with nothing after it: a faint dash, so the row still reads.
  Component {
    id: emptyValue
    Item {
      height: Math.round(Reading.body * 1.55)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u2014"
        textFormat: Text.PlainText
        color: Theme.ghost
        font.family: Reading.prose
        font.pixelSize: Math.round(Reading.body * 0.9)
      }
    }
  }

  Component {
    id: textValue
    RichText {
      property var field: parent && parent.field ? parent.field : ({ key: "", value: "", items: [] })
      runs: [{ t: field.value }]
      size: Math.round(Reading.body * 0.9)
      leading: 1.5
      topPadding: Math.max(0, Math.round((Reading.body * 1.55 - size * 1.5) / 2))
      baseColor: Theme.text
    }
  }
}
