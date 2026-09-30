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
    image: "blocks/ImageBlock.qml", html: "blocks/HtmlBlock.qml", frontmatter: "blocks/FrontMatter.qml",
    footnotes: "blocks/Footnotes.qml"
  })

  // Block types built so far (step 3 builds them one at a time).
  readonly property var ready: ["paragraph", "heading", "list", "quote", "alert", "code", "diff"]

  Component.onCompleted: {
    var src = sources[block.type] || "blocks/HtmlBlock.qml"
    if (ready.indexOf(block.type) < 0) src = "blocks/Pending.qml"
    setSource(Qt.resolvedUrl(src), { block: block, ctx: ctx, look: look })
  }
}
