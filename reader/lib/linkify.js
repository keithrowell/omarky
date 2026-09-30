.pragma library

// A small stand-in for linkify-it, whose matcher fails under Qt's V4 engine
// (test() is always false). markdown-it only calls pretest/test/match and
// matchAtStart; this recognises what GitHub autolinks in prose:
// scheme URLs (http, https, ftp), www. hosts and e-mail addresses.

var URL = /(?:(?:https?|ftp):\/\/|www\.)[^\s<>]*[^\s<>.,:;"'!?*_~\]]|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g

// Keep a closing parenthesis only when the URL opened one.
function trimParens(url) {
  var open = (url.match(/\(/g) || []).length
  var close = (url.match(/\)/g) || []).length
  while (close > open && url[url.length - 1] === ")") { url = url.slice(0, -1); close-- }
  return url
}

function make(text, index, raw) {
  var t = trimParens(raw)
  var url = t
  if (/^www\./i.test(t)) url = "http://" + t
  else if (t.indexOf("@") > 0 && !/^[a-z]+:\/\//i.test(t)) url = "mailto:" + t
  return { schema: "", index: index, lastIndex: index + t.length, raw: t, text: t, url: url }
}

function match(text) {
  var out = [], m
  URL.lastIndex = 0
  while ((m = URL.exec(text)) !== null) {
    // Not inside a word: "foo.www.x" and "a@b" glued to letters stay text.
    var before = m.index > 0 ? text[m.index - 1] : ""
    if (before && /[A-Za-z0-9]/.test(before) && m[0].indexOf("@") < 0) continue
    out.push(make(text, m.index, m[0]))
  }
  return out.length ? out : null
}

var linkify = {
  pretest: function(text) { return /:\/\/|www\.|@/i.test(text) },
  test: function(text) { return match(text) !== null },
  match: match,
  matchAtStart: function(text) {
    var all = match(text)
    return all && all[0].index === 0 ? all[0] : null
  },
  set: function() { return linkify }
}
