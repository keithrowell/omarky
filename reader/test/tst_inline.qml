import QtQuick
import QtTest
import "../lib/blocks.js" as Blocks
import "../lib/inline.js" as Inline

// lib/inline.js: inline tokens -> styled runs -> Qt rich text.
TestCase {
  name: "Inline"

  readonly property var tones: ({
    mono: "iA Writer Mono S", text: "#dddddd", strong: "#ffffff", dim: "#999999", faint: "#666666",
    link: "#7daea3", codeText: "#e0d0b0", codeBg: "#303030", codeSize: 15, rawText: "#888888"
  })

  function runsOf(src) { return Blocks.build(src).blocks[0].runs }

  function test_styles() {
    var r = runsOf("a **b** *c* ~~d~~ `e` ***f***")
    var byText = {}
    r.forEach(function(x) { byText[x.t] = x })
    verify(byText.b.b && !byText.b.i)
    verify(byText.c.i && !byText.c.b)
    verify(byText.d.s)
    verify(byText.e.code)
    verify(byText.f.b && byText.f.i)
    compare(Inline.plain(r), "a b c d e f")
  }

  function test_links_and_linkify() {
    var r = runsOf("[Omarchy](https://omarchy.org) and https://example.com and [rel](other.md#part)")
    var links = r.filter(function(x) { return x.href })
    compare(links.map(function(x) { return x.href }), ["https://omarchy.org", "https://example.com", "other.md#part"])
    compare(links[0].t, "Omarchy")
  }

  function test_linkify_edges() {
    var r = runsOf("See https://a.org/x. Or (https://en.wikipedia.org/wiki/Foo_(bar)), www.omarchy.org, keith@example.com; file.md is not a link.")
    var links = r.filter(function(x) { return x.href }).map(function(x) { return x.href })
    compare(links, ["https://a.org/x", "https://en.wikipedia.org/wiki/Foo_(bar)", "http://www.omarchy.org", "mailto:keith@example.com"])
  }

  function test_breaks() {
    var r = runsOf("one\ntwo\\\nthree")
    compare(Inline.plain(r), "one two\nthree")
    var html = Inline.toHtml(r, tones)
    verify(html.indexOf("<br />") > 0 || html.indexOf("<br>") > 0)
  }

  function test_escaping() {
    var html = Inline.toHtml(runsOf("a < b && c > d \\<tag>"), tones)
    verify(html.indexOf("&lt;") >= 0)
    verify(html.indexOf("&amp;&amp;") >= 0)
    verify(html.indexOf("<tag>") < 0)
  }

  function test_link_html_has_accent_and_no_underline() {
    var html = Inline.toHtml(runsOf("[x](https://a.b)"), tones)
    verify(html.indexOf("href=\"https://a.b\"") > 0)
    verify(html.indexOf("#7daea3") > 0)
    verify(html.indexOf("text-decoration:none") > 0)
    var hovered = Inline.toHtml(runsOf("[x](https://a.b)"), tones, { hover: "https://a.b" })
    verify(hovered.indexOf("text-decoration:underline") > 0)
  }

  function test_code_chip_html() {
    var html = Inline.toHtml(runsOf("use `md.parse()` here"), tones)
    verify(html.indexOf("iA Writer Mono S") > 0)
    verify(html.indexOf("md.parse()") > 0)
    compare(Inline.chipRanges(runsOf("use `md.parse()` here")), [[4, 16]])
    compare(Inline.chipRanges(runsOf("`a` and `bc`")), [[0, 3], [8, 12]])
  }

  function test_inline_html() {
    var r = runsOf("a <!-- hidden --> b<br>c <kbd>K</kbd>")
    compare(Inline.plain(r), "a  b\nc <kbd>K</kbd>")
    var raw = r.filter(function(x) { return x.raw })
    compare(raw.length, 2)
    var html = Inline.toHtml(r, tones)
    verify(html.indexOf("&lt;kbd&gt;") > 0, "raw html is shown literally")
  }

  function test_footnote_ref_is_superscript() {
    var html = Inline.toHtml(runsOf("x[^1]\n\n[^1]: n"), tones)
    verify(html.indexOf("<sup>") > 0 || html.indexOf("vertical-align:super") > 0)
    verify(html.indexOf("#fn-1") > 0)
  }

  function test_typographer() {
    compare(Inline.plain(runsOf("\"quoted\" -- and --- dash...")), "“quoted” – and — dash…")
  }

  function test_find_highlight_ranges() {
    var r = runsOf("alpha **beta** gamma beta")
    var html = Inline.toHtml(r, tones, { find: "beta", findBg: "#ffff00", current: 1, currentBg: "#ff8800" })
    compare(html.split("#ffff00").length - 1, 1)
    compare(html.split("#ff8800").length - 1, 1)
    compare(Inline.countMatches("alpha beta gamma beta", "BETA"), 2)
    var rs = runsOf("a `code` beta")
    compare(Inline.docPos(rs, 0), 0)
    compare(Inline.docPos(rs, 2), 3, "inside the chip, after its pad")
    compare(Inline.docPos(rs, 7), 9, "after the chip and both pads")
  }
}
