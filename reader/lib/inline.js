.pragma library

// Inline markdown-it tokens -> styled runs -> Qt rich text.

function runs(children) {
  var out = []
  var style = { b: 0, i: 0 }
  for (var i = 0; i < children.length; i++) {
    var t = children[i]
    if (t.type === "text") out.push({ t: t.content, b: style.b > 0, i: style.i > 0 })
    else if (t.type === "softbreak") out.push({ t: " " })
    else if (t.type === "strong_open") style.b++
    else if (t.type === "strong_close") style.b--
    else if (t.type === "em_open") style.i++
    else if (t.type === "em_close") style.i--
    else if (t.type === "code_inline") out.push({ t: t.content, code: true })
  }
  return out
}

function esc(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function toHtml(rs, tones) {
  var html = ""
  for (var i = 0; i < rs.length; i++) {
    var r = rs[i], s = esc(r.t)
    if (r.code) s = "<span style=\"font-family:'" + tones.mono + "'; background-color:" + tones.codeBg + ";\">" + s + "</span>"
    if (r.b) s = "<b>" + s + "</b>"
    if (r.i) s = "<i>" + s + "</i>"
    html += s
  }
  return html
}
