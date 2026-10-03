import QtQuick
import qs.services

// Chooses the component for one block by its type. Used by the document
// view and, recursively, by containers (list items, quotes, alerts).
Loader {
  id: root
  required property var block
  property var ctx: null
  // Inherited text treatment: { size, tier: text|dim, scale }.
  property var look: ({})

  readonly property var sources: ({
    paragraph: "blocks/Paragraph.qml", heading: "blocks/Heading.qml", list: "blocks/ListBlock.qml",
    quote: "blocks/Quote.qml", alert: "blocks/Alert.qml", code: "blocks/CodeBlock.qml",
    diff: "blocks/DiffBlock.qml", table: "blocks/TableBlock.qml", hr: "blocks/Rule.qml",
    image: "blocks/ImageBlock.qml", gallery: "blocks/GalleryBlock.qml", html: "blocks/HtmlBlock.qml", frontmatter: "blocks/FrontMatter.qml",
    footnotes: "blocks/Footnotes.qml"
  })

  Component.onCompleted: {
    var src = sources[block.type] || "blocks/HtmlBlock.qml"
    setSource(Qt.resolvedUrl(src), { block: block, ctx: ctx, look: look })
  }
}
