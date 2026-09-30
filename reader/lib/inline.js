.pragma library

// Inline markdown-it tokens -> styled runs -> Qt rich text.
//
// A run is one stretch of text with one style:
//   { t, b, i, s, code, href, fn, anchor, raw, br, soft }
// Runs keep the renderer honest: plain() is exactly the text the reader
// sees (find counts against it), and toHtml() paints it in the theme.

function runs(children) {
  var out = []
  var b = 0, i = 0, s = 0
  var links = []

  function push(r) {
    if (b > 0) r.b = true
    if (i > 0) r.i = true
    if (s > 0) r.s = true
    if (links.length && !r.href) r.href = links[links.length - 1]
    out.push(r)
  }

  for (var k = 0; k < (children || []).length; k++) {
    var t = children[k]
    switch (t.type) {
    case "text":
    case "text_special":
      if (t.content) push({ t: t.content })
      break
    case "softbreak": push({ t: " ", soft: true }); break
    case "hardbreak": push({ t: "\n", br: true }); break
    case "strong_open": b++; break
    case "strong_close": b = Math.max(0, b - 1); break
    case "em_open": i++; break
    case "em_close": i = Math.max(0, i - 1); break
    case "s_open": s++; break
    case "s_close": s = Math.max(0, s - 1); break
    case "link_open": links.push(t.attrGet("href") || ""); break
    case "link_close": links.pop(); break
    case "code_inline": push({ t: t.content, code: true }); break
    case "image":
      push({ t: t.content || t.attrGet("alt") || "image", img: t.attrGet("src") || "", href: links.length ? "" : t.attrGet("src") || "" })
      break
    case "html_inline":
      if (/^<!--/.test(t.content)) break
      if (/^<br\s*\/?>$/i.test(t.content)) push({ t: "\n", br: true })
      else push({ t: t.content, raw: true })
      break
    case "footnote_ref":
      var n = t.meta.id + 1
      push({ t: String(n), fn: true, href: "#fn-" + n, anchor: "fnref-" + n + "-" + (t.meta.subId + 1) })
      break
    default:
      if (t.content) push({ t: t.content })
    }
  }
  return out
}

function plain(rs) {
  var s = ""
  for (var i = 0; i < (rs || []).length; i++) s += rs[i].t
  return s
}

function esc(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

// Non-overlapping, case-insensitive match ranges of q in text.
function matchRanges(text, q) {
  var out = []
  if (!q) return out
  var hay = String(text).toLowerCase(), needle = String(q).toLowerCase()
  var at = hay.indexOf(needle)
  while (at >= 0) {
    out.push([at, at + needle.length])
    at = hay.indexOf(needle, at + needle.length)
  }
  return out
}

function countMatches(text, q) { return matchRanges(text, q).length }

// Paint one run's text, splitting it where find matches start and end.
function paintText(text, from, ranges, opts) {
  if (!ranges.length) return esc(text)
  var html = "", pos = 0
  var end = from + text.length
  for (var i = 0; i < ranges.length; i++) {
    var r = ranges[i]
    if (r[1] <= from || r[0] >= end) continue
    var a = Math.max(r[0], from) - from, z = Math.min(r[1], end) - from
    if (a > pos) html += esc(text.slice(pos, a))
    var bg = i === opts.current ? opts.currentBg : opts.findBg
    var fg = i === opts.current && opts.currentText ? "; color:" + opts.currentText : ""
    html += "<span style=\"background-color:" + bg + fg + "\">" + esc(text.slice(a, z)) + "</span>"
    pos = z
  }
  if (pos < text.length) html += esc(text.slice(pos))
  return html
}

// Runs -> Qt rich text. tones: { mono, text, strong, dim, link, codeText,
// codeBg, codeSize, rawText }. opts: { hover, find, findBg, current,
// currentBg, currentText }.
function toHtml(rs, tones, opts) {
  opts = opts || {}
  var ranges = opts.find ? matchRanges(plain(rs), opts.find) : []
  var html = "", at = 0
  for (var k = 0; k < (rs || []).length; k++) {
    var r = rs[k]
    var from = at
    at += r.t.length
    if (r.br) { html += "<br />"; continue }
    var s = paintText(r.t, from, ranges, opts)
    if (r.code) {
      s = "<span style=\"font-family:'" + tones.mono + "'; font-size:" + tones.codeSize + "px; color:" + tones.codeText +
          "; background-color:" + tones.codeBg + "\">&#8201;" + s + "&#8201;</span>"
    } else if (r.raw) {
      s = "<span style=\"font-family:'" + tones.mono + "'; font-size:" + tones.codeSize + "px; color:" + tones.rawText + "\">" + s + "</span>"
    }
    if (r.fn) s = "<sup>" + s + "</sup>"
    if (r.s) s = "<span style=\"text-decoration:line-through; color:" + tones.dim + "\">" + s + "</span>"
    if (r.i) s = "<i>" + s + "</i>"
    if (r.b) s = r.href ? "<b>" + s + "</b>" : "<b style=\"color:" + tones.strong + "\">" + s + "</b>"
    if (r.href) {
      var under = opts.hover && opts.hover === r.href ? "underline" : "none"
      s = "<a href=\"" + esc(r.href) + "\" style=\"color:" + tones.link + "; text-decoration:" + under + "\">" + s + "</a>"
    }
    html += s
  }
  return html
}
