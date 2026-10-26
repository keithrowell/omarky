import QtQuick
import QtTest
import "../lib/inline.js" as Inline
import "../lib/diff/changes.js" as Changes

TestCase {
  name: "Changes"

  function readFile(rel) {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", Qt.resolvedUrl(rel), false)
    xhr.send()
    return xhr.responseText
  }

  function changes(r) { return r.blocks.map(function(b) { return b.change }) }

  function test_words_added_and_removed_per_section() {
    var r = Changes.compare("# A\n\none two three\n\n# B\n\nkeep this line\n", "# A\n\none two\n\n# B\n\nkeep this line\n\nA new closing paragraph here.\n")
    var a = r.blocks[0], b = r.blocks.filter(function(x) { return x.type === "heading" && x.text === "B" })[0]
    compare(a.sectionIns, 0)
    compare(a.sectionDel, 1)
    compare(b.sectionIns, 5)
    compare(b.sectionDel, 0)
    var added = r.blocks[r.blocks.length - 1]
    compare(added.change, "added")
    compare(added.insWords, 5)
  }

  function test_paired_blocks_point_at_their_older_lines() {
    var r = Changes.compare("# A\n\nold words here\n\nsame\n", "# A\n\nAn inserted paragraph.\n\nnew words here\n\nsame\n")
    var reworded = r.blocks.filter(function(b) { return b.change === "reworded" })[0]
    compare(reworded.fromStart, 2)
    compare(reworded.fromEnd, 3)
    compare(reworded.srcStart, 4)
    var same = r.blocks[r.blocks.length - 1]
    compare(same.change, "same")
    compare(same.fromStart, 4)
    var added = r.blocks.filter(function(b) { return b.change === "added" })[0]
    compare(added.fromStart, undefined)
    var rm = Changes.compare("# A\n\ngone\n", "# A\n").blocks.filter(function(b) { return b.change === "removed" })[0]
    compare(rm.fromStart, 2)
    compare(rm.fromEnd, 3)
  }

  function test_identical_is_zero() {
    var r = Changes.compare("# A\n\nx y z\n", "# A\n\nx y z\n")
    compare(r.total, 0)
    verify(r.blocks.every(function(b) { return b.change === "same" }))
    compare(r.lineCount, 4)
    compare(r.source, "# A\n\nx y z\n")
  }

  function test_rewrap_is_zero() {
    var r = Changes.compare("# A\n\nThe quick brown fox\njumps over the lazy dog.\n", "# A\n\nThe quick brown fox jumps\nover the lazy dog.\n")
    compare(r.total, 0)
  }

  function test_reworded_paragraph() {
    var r = Changes.compare("# A\n\nWe propose a twelve-week plan.\n", "# A\n\nWe propose a ten-week plan.\n")
    compare(r.total, 1)
    compare(r.blocks[1].change, "reworded")
    compare(r.blocks[1].changes, 1)
    compare(Inline.plain(r.blocks[1].runs.filter(function(x) { return x.del })), "twelve")
    compare(Inline.plain(r.blocks[1].runs.filter(function(x) { return x.ins })), "ten")
  }

  function test_added_and_removed_paragraphs() {
    var r = Changes.compare("# A\n\nkeep\n\ngone away\n", "# A\n\nkeep\n\nbrand new\n")
    compare(r.total, 2)
    compare(changes(r), ["same", "same", "removed", "added"])
    verify(r.blocks[2].runs.every(function(x) { return x.del }))
    // The removed block sits on the line of the block that follows it.
    compare(r.blocks[2].srcStart, r.blocks[3].srcStart)
  }

  function test_removed_at_end_sits_after_the_last_block() {
    var r = Changes.compare("keep\n\ngone\n", "keep\n")
    compare(changes(r), ["same", "removed"])
    compare(r.blocks[1].srcStart, r.blocks[0].srcEnd)
  }

  function test_empty_from_is_all_added() {
    var r = Changes.compare("", "# A\n\nx\n")
    compare(changes(r), ["added", "added"])
    compare(r.total, 2)
  }

  function test_empty_to_is_all_removed() {
    var r = Changes.compare("# A\n\nx\n", "")
    compare(changes(r), ["removed", "removed"])
    compare(r.total, 2)
    compare(r.lineCount, 1)
  }

  function test_both_empty() {
    var r = Changes.compare("", "")
    compare(r.blocks, [])
    compare(r.total, 0)
  }

  function test_list_items() {
    var r = Changes.compare("- weeks 1 to 4\n- weeks 5 to 8\n- same\n", "- weeks 1 to 3\n- weeks 4 to 6\n- same\n")
    compare(r.total, 2)
    compare(r.blocks[0].change, "reworded")
    compare(r.blocks[0].changes, 2)
    compare(r.blocks[0].items.map(function(it) { return it.change }), ["reworded", "reworded", "same"])
    var first = r.blocks[0].items[0].blocks[0]
    compare(Inline.plain(first.runs.filter(function(x) { return x.del })), "4")
    compare(Inline.plain(first.runs.filter(function(x) { return x.ins })), "3")
  }

  function test_list_item_added_and_removed() {
    var r = Changes.compare("- one\n- two\n- three\n", "- one\n- three\n- four\n")
    compare(r.blocks[0].changes, 2)
    compare(r.blocks[0].items.map(function(it) { return it.change }), ["same", "removed", "same", "added"])
    compare(Inline.plain(r.blocks[0].items[1].blocks[0].runs), "two")
    verify(r.blocks[0].items[1].blocks[0].runs.every(function(x) { return x.del }))
  }

  function test_whole_list_items_carry_the_change() {
    var same = Changes.compare("- a\n- b\n", "- a\n- b\n")
    compare(same.blocks[0].items.map(function(it) { return it.change }), ["same", "same"])
    var added = Changes.compare("x\n", "x\n\n- a\n  - nested\n- b\n")
    compare(added.blocks[1].change, "added")
    compare(added.blocks[1].items.map(function(it) { return it.change }), ["added", "added"])
    compare(added.blocks[1].items[0].blocks[1].items[0].change, "added")
    var removed = Changes.compare("x\n\n- a\n- b\n", "x\n")
    compare(removed.blocks[1].change, "removed")
    compare(removed.blocks[1].items.map(function(it) { return it.change }), ["removed", "removed"])
    verify(removed.blocks[1].items[0].blocks[0].runs.every(function(r) { return r.del }))
  }

  function test_retitled_section_pairs() {
    var r = Changes.compare("## Our approach\n\nbody\n", "## The approach\n\nbody\n")
    compare(r.blocks.length, 2)
    compare(r.blocks[0].change, "reworded")
    compare(r.blocks[1].change, "same")
    compare(r.total, 1)
  }

  function test_retitled_section_pairs_by_title_words() {
    var r = Changes.compare("## Our approach to the work\n\nold body\n", "## The approach to the work\n\nnew body\n")
    compare(r.blocks.length, 2)
    compare(r.blocks[0].change, "reworded")
    compare(Inline.plain(r.blocks[0].runs.filter(function(x) { return x.del })), "Our")
    compare(r.blocks[0].text, "The approach to the work")
  }

  function test_unrelated_sections_are_removed_and_added() {
    var r = Changes.compare("## Alpha\n\none two three\n", "## Omega\n\nfour five six\n")
    compare(changes(r), ["removed", "removed", "added", "added"])
    compare(r.total, 4)
  }

  function test_table_cell() {
    var r = Changes.compare("| a | b |\n|---|---|\n| 1 | 2 |\n", "| a | b |\n|---|---|\n| 1 | 3 |\n")
    compare(r.total, 1)
    compare(r.blocks[0].change, "reworded")
    compare(Inline.plain(r.blocks[0].rows[0][1].filter(function(x) { return x.ins })), "3")
    compare(Inline.plain(r.blocks[0].rows[0][1].filter(function(x) { return x.del })), "2")
  }

  function test_table_row_added() {
    var r = Changes.compare("| a | b |\n|---|---|\n| 1 | 2 |\n", "| a | b |\n|---|---|\n| 1 | 2 |\n| 7 | 8 |\n")
    compare(r.blocks[0].change, "reworded")
    compare(r.blocks[0].rows.length, 2)
    verify(r.blocks[0].rows[1].every(function(cell) { return cell.every(function(x) { return x.ins }) }))
  }

  function test_code_becomes_diff() {
    var r = Changes.compare("```sh\na\nb\n```\n", "```sh\na\nc\n```\n")
    compare(r.blocks[0].type, "diff")
    compare(r.blocks[0].change, "reworded")
    compare(r.blocks[0].lines.map(function(l) { return l.kind }), ["ctx", "del", "add"])
    compare(r.blocks[0].added, 1)
    compare(r.blocks[0].removed, 1)
    compare(r.blocks[0].lang, "sh")
  }

  function test_removed_code_is_a_diff_of_deleted_lines() {
    var r = Changes.compare("x\n\n```\na\nb\n```\n", "x\n")
    compare(r.blocks[1].type, "diff")
    compare(r.blocks[1].change, "removed")
    compare(r.blocks[1].lines.map(function(l) { return l.kind }), ["del", "del"])
  }

  function test_quote_children_pair() {
    var r = Changes.compare("> same line\n>\n> old words here\n", "> same line\n>\n> new words here\n")
    compare(r.blocks[0].type, "quote")
    compare(r.blocks[0].change, "reworded")
    compare(r.blocks[0].blocks.length, 2)
    compare(Inline.plain(r.blocks[0].blocks[1].runs.filter(function(x) { return x.del })), "old")
  }

  function test_image_source_change_is_removed_and_added() {
    var r = Changes.compare("![alt](a.png)\n", "![alt](b.png)\n")
    compare(changes(r), ["removed", "added"])
  }

  function test_section_counts_and_document() {
    var r = Changes.compare("# T\n\n## A\n\nold text here\n\n### A1\n\nx\n\n## B\n\nz\n", "# T\n\n## A\n\nnew text here\n\n### A1\n\nx y\n\n## B\n\nz\n")
    var d = Changes.document(r)
    var byText = {}
    d.headings.forEach(function(h) { byText[h.text] = h })
    compare(r.blocks[byText.T.index].sectionChanges, 2)
    compare(r.blocks[byText.A.index].sectionChanges, 2)
    compare(r.blocks[byText.A1.index].sectionChanges, 1)
    compare(r.blocks[byText.B.index].sectionChanges, 0)
    compare(Changes.changedIndices(r.blocks).length, 2)
    verify(d.pieces.length > 0)
    compare(d.headings.map(function(h) { return h.slug }), ["t", "a", "a1", "b"])
    compare(d.anchors.a1, byText.A1.index)
    compare(d.lineCount, r.lineCount)
    compare(d.source, r.source)
  }

  function test_section_count_includes_its_own_retitle() {
    var r = Changes.compare("## Our approach to the work\n\nsame\n", "## The approach to the work\n\nsame\n")
    compare(r.blocks[0].sectionChanges, 1)
  }

  function test_samples() {
    var before = readFile("../samples/changes/proposal-before.md"), after = readFile("../samples/changes/proposal-after.md")
    verify(before.length > 500 && after.length > 500, "samples read")
    var r = Changes.compare(before, after)
    verify(r.total >= 6, "total " + r.total)
    var d = Changes.document(r)
    var approach = d.headings.filter(function(h) { return h.text === "Approach" })[0]
    verify(approach, "Approach heading present")
    verify(r.blocks[approach.index].sectionChanges >= 4, "Approach changes " + r.blocks[approach.index].sectionChanges)
    var title = d.headings.filter(function(h) { return h.level === 1 })[0]
    compare(r.blocks[title.index].sectionChanges, r.total)
    // Every emitted block carries its marks.
    verify(r.blocks.every(function(b) { return typeof b.change === "string" && typeof b.changes === "number" }))
  }

  function test_long_document_is_fast() {
    var paras = [], i, w
    for (i = 0; i < 400; i++) {
      if (i % 20 === 0) paras.push("## Section " + (i / 20))
      var words = []
      for (w = 0; w < 50; w++) words.push("word" + ((i * 7 + w * 13) % 900))
      paras.push(words.join(" "))
    }
    var from = paras.join("\n\n") + "\n"
    var edited = paras.slice()
    edited[30] = edited[30].replace("word", "changed")
    edited[200] = edited[200] + " and more"
    edited.splice(300, 1)
    edited.splice(100, 0, "A brand new paragraph in the middle.")
    var to = edited.join("\n\n") + "\n"
    var t0 = Date.now()
    var r = Changes.compare(from, to)
    var ms = Date.now() - t0
    verify(ms < 1000, "compare of 20k words took " + ms + " ms")
    compare(r.total, 4)
  }

  function test_rewrite_pairs_a_lone_block_word_by_word() {
    var out = Changes.rewrite("The first paragraph is long-winded.", "A plainer paragraph.")
    compare(out.length, 1)
    compare(out[0].change, "reworded")
    verify(out[0].runs.some(function(r) { return r.del }))
    verify(out[0].runs.some(function(r) { return r.ins }))
  }

  function test_rewrite_of_several_blocks_compares_them() {
    var out = Changes.rewrite("One.\n\nTwo.", "One.\n\nTwo and more.\n\nThree.")
    compare(out.map(function(b) { return b.change }).join(","), "same,reworded,added")
  }
}
