import QtQuick
import QtTest
import "../lib/blocks.js" as Blocks
import "../lib/inline.js" as Inline

// lib/blocks.js: markdown-it tokens -> the flat block list.
TestCase {
  name: "Blocks"

  function readSample(rel) {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", Qt.resolvedUrl("../samples/" + rel), false)
    xhr.send()
    return xhr.responseText
  }

  function types(doc) { return doc.blocks.map(function(b) { return b.type }) }
  function plain(runs) { return Inline.plain(runs) }

  function test_paragraphs_and_line_map() {
    var doc = Blocks.build("One line.\n\nTwo\nlines.\n")
    compare(types(doc), ["paragraph", "paragraph"])
    compare(doc.blocks[0].srcStart, 0)
    compare(doc.blocks[0].srcEnd, 1)
    compare(doc.blocks[1].srcStart, 2)
    compare(doc.blocks[1].srcEnd, 4)
    compare(plain(doc.blocks[1].runs), "Two lines.")
    compare(doc.lineCount, 5)
  }

  function test_headings_levels_and_slugs() {
    var doc = Blocks.build("# Hello, World!\n\n## Hello, World!\n\n### `code` and _emph_\n\n#### Café Ünïcode — dash\n\n##### Hello, World!\n")
    compare(types(doc), ["heading", "heading", "heading", "heading", "heading"])
    compare(doc.blocks.map(function(b) { return b.level }), [1, 2, 3, 4, 5])
    compare(doc.blocks[0].slug, "hello-world")
    compare(doc.blocks[1].slug, "hello-world-1")
    compare(doc.blocks[2].slug, "code-and-emph")
    compare(doc.blocks[3].slug, "café-ünïcode--dash")
    compare(doc.blocks[4].slug, "hello-world-2")
    compare(doc.blocks[2].text, "code and emph")
  }

  function test_outline_lists_headings_with_block_indexes() {
    var doc = Blocks.build("# A\n\ntext\n\n## B\n\n### C\n")
    compare(doc.headings.length, 3)
    compare(doc.headings[1].text, "B")
    compare(doc.headings[1].level, 2)
    compare(doc.headings[1].index, 2)
    compare(doc.headings[2].slug, "c")
  }

  function test_front_matter_card() {
    var doc = Blocks.build(readSample("frontmatter.md"))
    var fm = doc.blocks[0]
    compare(fm.type, "frontmatter")
    compare(fm.title, "Render each Markdown block as its own native component")
    compare(fm.srcStart, 0)
    compare(fm.srcEnd, 18)
    var byKey = {}
    fm.fields.forEach(function(f) { byKey[f.key] = f })
    verify(!byKey.title, "title is lifted out of the rows")
    compare(byKey.status.kind, "pill")
    compare(byKey.status.value, "accepted")
    compare(byKey.date.kind, "pill")
    compare(byKey.number.value, "0001")
    compare(byKey.deciders.kind, "list")
    compare(byKey.deciders.items, ["OmaRead maintainers"])
    compare(byKey.tags.items, ["rendering", "performance", "typography"])
    compare(byKey.summary.kind, "text")
    verify(byKey.summary.value.indexOf("The document is a flat list") === 0)
    verify(byKey.summary.value.indexOf("\n") < 0, "folded scalar joins lines")
    compare(byKey.links.kind, "link")
    compare(byKey.draft.value, "false")
    // The heading after the front matter keeps its real source line.
    compare(doc.blocks[1].type, "heading")
    compare(doc.blocks[1].srcStart, 19)
  }

  function test_front_matter_only_at_top() {
    var doc = Blocks.build("Intro\n\n---\ntitle: nope\n---\n")
    verify(types(doc).indexOf("frontmatter") < 0)
  }

  function test_unclosed_front_matter_is_not_front_matter() {
    var doc = Blocks.build("---\ntitle: x\n\nNo closing fence.\n")
    verify(types(doc).indexOf("frontmatter") < 0)
    verify(doc.blocks.length > 0)
  }

  function test_html_comments_hidden_other_html_literal() {
    var doc = Blocks.build("<!-- SNAPSHOT abc -->\n\nText\n\n<div class=\"x\">hi</div>\n\n<!-- a\nmultiline comment -->\n")
    compare(types(doc), ["paragraph", "html"])
    compare(doc.blocks[1].text, "<div class=\"x\">hi</div>")
  }

  function test_unclosed_comment_stays_visible() {
    var doc = Blocks.build("<!-- never closed\n\n# Still here\n")
    compare(types(doc), ["html"])
    verify(doc.blocks[0].text.indexOf("Still here") > 0)
  }

  function test_lists_tight_loose_ordered_nested() {
    var doc = Blocks.build("- a\n- b\n  - b1\n    - b2\n- c\n\n8. x\n9. y\n\n- p\n\n- q\n")
    compare(types(doc), ["list", "list", "list"])
    var ul = doc.blocks[0]
    compare(ul.ordered, false)
    compare(ul.tight, true)
    compare(ul.items.length, 3)
    compare(ul.depth, 0)
    var nested = ul.items[1].blocks[1]
    compare(nested.type, "list")
    compare(nested.depth, 1)
    compare(nested.items[0].blocks[1].depth, 2)
    compare(plain(ul.items[1].blocks[0].runs), "b")
    var ol = doc.blocks[1]
    compare(ol.ordered, true)
    compare(ol.start, 8)
    compare(ol.items[1].number, 9)
    compare(doc.blocks[2].tight, false)
  }

  function test_task_items() {
    var doc = Blocks.build("- [x] done\n- [ ] todo\n- [X] Done too\n- not a task\n- [y] nor this\n")
    var items = doc.blocks[0].items
    compare(items.map(function(i) { return i.task }), ["done", "todo", "done", "", ""])
    compare(plain(items[0].blocks[0].runs), "done")
    compare(plain(items[4].blocks[0].runs), "[y] nor this")
    verify(doc.blocks[0].tasks)
  }

  function test_blockquote_nesting() {
    var doc = Blocks.build("> outer\n>\n> > inner\n")
    compare(types(doc), ["quote"])
    var q = doc.blocks[0]
    compare(q.blocks[0].type, "paragraph")
    compare(q.blocks[1].type, "quote")
    compare(plain(q.blocks[1].blocks[0].runs), "inner")
  }

  function test_alerts() {
    var doc = Blocks.build(readSample("alerts.md"))
    var alerts = doc.blocks.filter(function(b) { return b.type === "alert" })
    compare(alerts.map(function(a) { return a.kind }), ["note", "tip", "important", "warning", "caution"])
    compare(alerts[0].title, "Note")
    compare(plain(alerts[0].blocks[0].runs), "Useful information that users should know, even when skimming content.")
    compare(alerts[2].blocks[1].type, "list")
    compare(alerts[4].blocks[1].type, "code")
    var quotes = doc.blocks.filter(function(b) { return b.type === "quote" })
    compare(quotes.length, 3)
    compare(plain(quotes[0].blocks[0].runs).indexOf("[!UNKNOWN]"), 0)
  }

  function test_code_blocks() {
    var doc = Blocks.build("```python\ndef f():\n    pass\n```\n\n```\nplain\n```\n\n    indented\n\n```mermaid\ngraph LR\n```\n")
    compare(types(doc), ["code", "code", "code", "code"])
    compare(doc.blocks[0].lang, "python")
    compare(doc.blocks[0].text, "def f():\n    pass")
    compare(doc.blocks[0].lineCount, 2)
    compare(doc.blocks[1].lang, "")
    compare(doc.blocks[2].text, "indented")
    compare(doc.blocks[3].lang, "mermaid")
  }

  function test_diff_blocks() {
    var doc = Blocks.build("```diff\ndiff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1,2 +1,2 @@\n same\n-old\n+new\n+newer\n```\n")
    var d = doc.blocks[0]
    compare(d.type, "diff")
    compare(d.added, 2)
    compare(d.removed, 1)
    compare(d.lines.map(function(l) { return l.kind }), ["meta", "meta", "meta", "hunk", "ctx", "del", "add", "add"])
    compare(d.lines[5].text, "old")
    compare(d.lines[4].text, "same")
  }

  function test_tables() {
    var doc = Blocks.build("| L | C | R | N |\n|:--|:-:|--:|---|\n| a | **b** | 1.5 | 10 |\n| c | d | 22 | 3 |\n| only |\n")
    var t = doc.blocks[0]
    compare(t.type, "table")
    compare(t.aligns, ["left", "center", "right", ""])
    compare(t.header.map(plain), ["L", "C", "R", "N"])
    compare(t.rows.length, 3)
    compare(t.rows[2].length, 4, "ragged rows are padded")
    compare(plain(t.rows[0][1]), "b")
    compare(t.numeric, [false, false, true, true])
  }

  function test_rule_and_images() {
    var doc = Blocks.build("---\n\n![Alt text](pic.png \"Title\")\n\nText with ![inline](i.png) image.\n")
    compare(types(doc), ["hr", "image", "paragraph"])
    compare(doc.blocks[1].src, "pic.png")
    compare(doc.blocks[1].alt, "Alt text")
    compare(doc.blocks[1].title, "Title")
  }

  function test_footnotes() {
    var doc = Blocks.build("First[^b] and second[^a], again[^b].\n\n[^a]: Note A.\n[^b]: Note B\n    continues.\n\n[^unused]: Never cited.\n")
    var t = types(doc)
    compare(t, ["paragraph", "footnotes"])
    var runs = doc.blocks[0].runs.filter(function(r) { return r.fn })
    compare(runs.map(function(r) { return r.t }), ["1", "2", "1"])
    compare(runs[0].href, "#fn-1")
    compare(runs[2].anchor, "fnref-1-2")
    var notes = doc.blocks[1]
    compare(notes.items.map(function(i) { return i.label }), ["b", "a", "unused"])
    compare(notes.items[0].number, 1)
    compare(notes.items[0].refs, 2)
    compare(plain(notes.items[0].blocks[0].runs), "Note B continues.")
    compare(notes.items[2].refs, 0)
  }

  function test_anchor_map() {
    var doc = Blocks.build("# Top\n\nCited[^n].\n\n- in a list[^m]\n\n## Top\n\n[^n]: Note.\n[^m]: Other.\n")
    compare(doc.anchors["top"], 0)
    compare(doc.anchors["top-1"], 3)
    compare(doc.anchors["fnref-1-1"], 1)
    compare(doc.anchors["fnref-2-1"], 2)
    compare(doc.anchors["fn-1"], 4)
    compare(doc.anchors["fn-2"], 4)
  }

  function test_find_index_stamps_piece_ids_in_document_order() {
    var doc = Blocks.build("# Beta\n\nalpha beta\n\n- beta one\n- two\n\n| h | beta |\n|---|---|\n| beta | x |\n\n```\nbeta = 1\nbeta\n```\n")
    var idx = doc.pieces
    compare(idx.map(function(p) { return p.text }), ["Beta", "alpha beta", "beta one", "two", "h", "beta", "beta", "x", "beta = 1\nbeta"])
    compare(idx.map(function(p) { return p.pid }), [0, 1, 2, 3, 4, 5, 6, 7, 8])
    compare(idx.map(function(p) { return p.block }), [0, 1, 2, 2, 3, 3, 3, 3, 4])
    compare(doc.blocks[0].pid, 0)
    compare(doc.blocks[2].items[1].blocks[0].pid, 3)
    compare(doc.blocks[3].headerPids, [4, 5])
    compare(doc.blocks[3].rowPids, [[6, 7]])
    compare(doc.blocks[4].pid, 8)
    var m = Blocks.findAll(doc, "BETA")
    compare(m.length, 7)
    compare(m[0].pid, 0)
    compare(m[5], { pid: 8, block: 4, k: 0 })
    compare(m[6], { pid: 8, block: 4, k: 1 })
    compare(Blocks.findAll(doc, "").length, 0)
  }

  function test_every_sample_builds() {
    var names = ["kitchen-sink.md", "prose.md", "code.md", "tables.md", "alerts.md", "frontmatter.md",
                 "malformed.md", "empty.md", "real/omaread-spec.md"]
    for (var i = 0; i < names.length; i++) {
      var doc = Blocks.build(readSample(names[i]))
      verify(doc.blocks instanceof Array, names[i])
      if (names[i] !== "empty.md") verify(doc.blocks.length > 0, names[i] + " has blocks")
      for (var j = 0; j < doc.blocks.length; j++) {
        verify(typeof doc.blocks[j].srcStart === "number", names[i] + " block " + j + " has srcStart")
        verify(doc.blocks[j].srcEnd >= doc.blocks[j].srcStart, names[i] + " block " + j + " line map")
      }
    }
  }

  function test_kitchen_sink_has_every_block_type() {
    var doc = Blocks.build(readSample("kitchen-sink.md"))
    var seen = {}
    doc.blocks.forEach(function(b) { seen[b.type] = true })
    var want = ["frontmatter", "heading", "paragraph", "list", "quote", "alert", "code", "diff",
                "table", "hr", "image", "html", "footnotes"]
    for (var i = 0; i < want.length; i++) verify(seen[want[i]], "kitchen sink has " + want[i])
  }

  function test_malformed_input() {
    var doc = Blocks.build(readSample("malformed.md"))
    verify(doc.blocks.length > 10)
    var last = doc.blocks[doc.blocks.length - 1]
    compare(last.type, "code", "an unclosed fence runs to the end")
    compare(Blocks.build("").blocks.length, 0)
    compare(Blocks.build("\u0000\u0001� binary").blocks.length, 1)
    compare(Blocks.build(null).blocks.length, 0)
  }

  function test_long_document_is_fast() {
    var src = readSample("long.md")
    var t0 = Date.now()
    var doc = Blocks.build(src)
    var ms = Date.now() - t0
    verify(doc.lineCount > 5000)
    verify(doc.blocks.length > 1000, "blocks: " + doc.blocks.length)
    verify(ms < 900, "long.md built in " + ms + " ms")
    console.info("long.md: " + doc.blocks.length + " blocks in " + ms + " ms")
  }
}
