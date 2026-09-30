.pragma library
.import "../vendor/markdown-it.js" as MDI

// The markdown-it instance OmaRead parses with. Raw HTML is recognised
// (html: true) only so comments can be hidden and the rest shown as
// literal text; nothing is ever rendered as HTML (docs/decisions/0002).

var _md = null

function parser() {
  if (_md) return _md
  _md = MDI.get()({ html: true, linkify: true, typographer: true })
  return _md
}

function parse(src, env) {
  return parser().parse(String(src || ""), env || {})
}
