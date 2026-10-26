import QtQuick
import QtTest
import "../lib/editing.js" as E

// lib/editing.js: list continuation, indenting, wrapping, headings, counts.
TestCase {
  name: "Editing"

  function apply(text, r) { return text.slice(0, r.start) + r.insert + text.slice(r.end) }

  function test_enter_continues_bullets() {
    var t = "- one"
    var r = E.enter(t, 5)
    compare(apply(t, r), "- one\n- ")
    compare(r.cursor, 8)
  }

  function test_enter_numbers_and_tasks() {
    compare(apply("3. three", E.enter("3. three", 8)), "3. three\n4. ")
    compare(apply("  - [x] done", E.enter("  - [x] done", 12)), "  - [x] done\n  - [ ] ")
    compare(apply("> quoted", E.enter("> quoted", 8)), "> quoted\n> ")
  }

  function test_enter_on_empty_item_ends_list() {
    var t = "- one\n- "
    var r = E.enter(t, t.length)
    compare(apply(t, r), "- one\n")
    compare(r.cursor, 6)
  }

  function test_enter_plain_and_inside_marker() {
    compare(E.enter("hello", 5), null)
    compare(E.enter("- one", 1), null)
  }

  function test_indent() {
    compare(apply("- one", E.indent("- one", 3, false)), "  - one")
    compare(apply("  - one", E.indent("  - one", 5, true)), "- one")
    compare(apply("1. one", E.indent("1. one", 4, false)), "   1. one")
    compare(E.indent("plain", 2, false), null)
    compare(E.indent("- top", 2, true), null)
  }

  function test_wrap() {
    var r = E.wrap("make bold here", 5, 9, "**")
    compare(apply("make bold here", r), "make **bold** here")
    compare([r.selStart, r.selEnd], [7, 11])
    var back = E.wrap("make **bold** here", 7, 11, "**")
    compare(apply("make **bold** here", back), "make bold here")
    var empty = E.wrap("ab", 1, 1, "*")
    compare(apply("ab", empty), "a**b")
    compare(empty.selStart, 2)
  }

  function test_link() {
    var r = E.link("see docs", 4, 8)
    compare(apply("see docs", r), "see [docs]()")
    compare(r.selStart, 11)
    var u = E.link("x https://a.b y", 2, 13)
    compare(apply("x https://a.b y", u), "x [](https://a.b) y")
  }

  function test_heading() {
    compare(apply("Title", E.heading("Title", 2, 2)), "## Title")
    compare(apply("## Title", E.heading("## Title", 5, 1)), "# Title")
    compare(apply("## Title", E.heading("## Title", 5, 2)), "Title")
    compare(apply("# Title", E.heading("# Title", 3, 0)), "Title")
  }

  function test_stats() {
    var s = E.stats("---\ntitle: x\n---\n# Hello world\n\nIt's a [link](http://x.y) and `code`.\n")
    compare(s.words, 7)
    compare(E.stats("").words, 0)
    compare(E.stats("one").minutes, 1)
  }

  function test_word_at() {
    compare(E.wordAt("say don't go", 6).word, "don't")
    compare(E.wordAt("  ", 1), null)
    compare(E.wordAt("'quoted'", 3).word, "quoted")
  }

  function test_find_and_lines() {
    compare(E.findAll("Aa aA", "aa"), [0, 3])
    compare(E.lineNumber("a\nb\nc", 4), 2)
  }
}
