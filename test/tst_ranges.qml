import QtQuick
import QtTest
import "../lib/ranges.js" as R

// lib/ranges.js: the block, section and widening a rewrite works on.
TestCase {
  name: "Ranges"

  readonly property string doc: "# Title\n\nIntro para.\n\n## One\n\nFirst para\nwraps here.\n\n- a\n- b\n\n### Deep\n\nDeep para.\n\n## Two\n\nLast para."

  function cut(r) { return doc.slice(r.start, r.end) }

  function test_block_is_the_paragraph() {
    var r = R.blockAt(doc, doc.indexOf("wraps"))
    compare(cut(r), "First para\nwraps here.")
    compare(r.kind, "block")
  }

  function test_block_is_the_whole_list() {
    compare(cut(R.blockAt(doc, doc.indexOf("- b"))), "- a\n- b")
  }

  function test_blank_line_takes_the_next_block() {
    compare(cut(R.blockAt(doc, doc.indexOf("Intro") - 1)), "Intro para.")
  }

  function test_section_runs_to_the_next_heading_of_its_level() {
    var r = R.sectionAt(doc, doc.indexOf("First"))
    compare(cut(r), "## One\n\nFirst para\nwraps here.\n\n- a\n- b\n\n### Deep\n\nDeep para.")
  }

  function test_section_of_a_subsection() {
    compare(cut(R.sectionAt(doc, doc.indexOf("Deep para"))), "### Deep\n\nDeep para.")
  }

  function test_selection_widens_to_words() {
    var a = doc.indexOf("ntro"), b = doc.indexOf("para.") + 2
    compare(cut(R.words(doc, a, b)), "Intro para")
  }

  function test_widen_climbs_block_section_outer_document() {
    var pos = doc.indexOf("Deep para")
    var r = R.words(doc, pos, pos + 4)
    r = R.widen(doc, r, pos); compare(cut(r), "Deep para.")
    r = R.widen(doc, r, pos); compare(cut(r), "### Deep\n\nDeep para.")
    r = R.widen(doc, r, pos); compare(r.kind, "section"); verify(cut(r).indexOf("## One") === 0)
    r = R.widen(doc, r, pos); verify(cut(r).indexOf("# Title") === 0)
    r = R.widen(doc, r, pos); compare(r.kind, "document"); compare(cut(r), doc)
  }

  function test_locate_follows_a_moved_range() {
    var t = "xx " + doc
    compare(R.locate(t, "Intro para.", doc.indexOf("Intro")), doc.indexOf("Intro") + 3)
    compare(R.locate(t, "gone", 4), -1)
  }

  function test_empty_document() {
    var r = R.blockAt("", 0)
    compare(r.start, 0); compare(r.end, 0)
  }
}
