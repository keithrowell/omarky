.pragma library
.import "markdown.js" as Markdown
.import "inline.js" as Inline

// markdown-it tokens -> a flat array of block objects (see docs/spec.md §4).

function build(src) {
  var tokens = Markdown.parse(src, {})
  var blocks = []
  for (var i = 0; i < tokens.length; i++) {
    var t = tokens[i]
    if (t.type === "inline" && t.level === 1) {
      var map = tokens[i - 1].map || [0, 0]
      blocks.push({ type: "paragraph", runs: Inline.runs(t.children || []), srcStart: map[0], srcEnd: map[1] })
    }
  }
  return { blocks: blocks }
}
