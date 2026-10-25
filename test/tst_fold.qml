import QtQuick
import QtTest
import "../lib/diff/changes.js" as Changes
import "../lib/diff/fold.js" as Fold

TestCase {
  name: "Fold"

  function shape(f) {
    return f.map(function(b) { return b.type + (b.type === "fold" ? ":" + (b.heading ? "section" : b.count) : "") })
  }

  function test_folds_runs_and_sections() {
    var r = Changes.compare("# T\n\n## A\n\na\n\nb\n\nc old\n\nd\n\n## B\n\nx\n\ny\n", "# T\n\n## A\n\na\n\nb\n\nc new\n\nd\n\n## B\n\nx\n\ny\n")
    var f = Fold.fold(r.blocks, {})
    compare(shape(f), ["heading", "heading", "fold:2", "paragraph", "fold:1", "fold:section"])
    compare(f[2].index, 2)
    compare(f[2].kinds, "paragraph")
    compare(f[2].count, 2)
    compare(f[2].change, "same")
    compare(f[2].changes, 0)
    compare(f[3].index, 4)
    compare(f[4].index, 5)
    // The section fold keeps its heading and counts the body it hides.
    compare(f[5].heading.text, "B")
    compare(f[5].index, 6)
    compare(f[5].count, 2)
    compare(f[5].srcStart, r.blocks[6].srcStart)
    compare(f[5].srcEnd, r.blocks[8].srcEnd)
    // Unchanged rows keep their unfolded index.
    compare(f[0].index, 0)
    compare(f[1].index, 1)
  }

  function test_open_keeps_a_run() {
    var r = Changes.compare("a\n\nb\n\nc old\n", "a\n\nb\n\nc new\n")
    var f = Fold.fold(r.blocks, { 0: true })
    compare(f.map(function(b) { return b.type }), ["paragraph", "paragraph", "paragraph"])
    // Any index inside the run opens the whole run.
    var g = Fold.fold(r.blocks, { 1: true })
    compare(g.map(function(b) { return b.type }), ["paragraph", "paragraph", "paragraph"])
    compare(g.map(function(b) { return b.index }), [0, 1, 2])
  }

  function test_open_keeps_a_section() {
    var r = Changes.compare("## A\n\nx\n\n## B\n\nold\n", "## A\n\nx\n\n## B\n\nnew\n")
    compare(shape(Fold.fold(r.blocks, {})), ["fold:section", "heading", "paragraph", "paragraph"])
    compare(shape(Fold.fold(r.blocks, { 0: true })), ["heading", "fold:1", "heading", "paragraph", "paragraph"])
    compare(shape(Fold.fold(r.blocks, { 0: true, 1: true })), ["heading", "paragraph", "heading", "paragraph", "paragraph"])
  }

  function test_section_fold_covers_subsections() {
    var r = Changes.compare("## A\n\nx\n\n### A1\n\ny\n\n## B\n\nold\n", "## A\n\nx\n\n### A1\n\ny\n\n## B\n\nnew\n")
    var f = Fold.fold(r.blocks, {})
    compare(shape(f), ["fold:section", "heading", "paragraph", "paragraph"])
    compare(f[0].count, 3)
    compare(f[1].index, 4)
  }

  function test_mixed_kinds_fold_as_blocks() {
    var r = Changes.compare("a\n\n- i\n\nold\n", "a\n\n- i\n\nnew\n")
    var f = Fold.fold(r.blocks, {})
    compare(shape(f), ["fold:2", "paragraph", "paragraph"])
    compare(f[0].kinds, "block")
  }

  function test_nothing_changed_folds_to_one_row() {
    var r = Changes.compare("a\n\nb\n", "a\n\nb\n")
    compare(shape(Fold.fold(r.blocks, {})), ["fold:2"])
    compare(Fold.fold([], {}), [])
  }

  function test_unfolded_index_and_open_range() {
    var r = Changes.compare("# T\n\n## A\n\na\n\nb\n\nc old\n\n## B\n\nx\n\ny\n", "# T\n\n## A\n\na\n\nb\n\nc new\n\n## B\n\nx\n\ny\n")
    // "c old" against "c new" is one reworded paragraph (Dice 0.5), so the
    // unfolded indices are T0 A1 a2 b3 c4 B5 x6 y7.
    var f = Fold.fold(r.blocks, {})
    compare(shape(f), ["heading", "heading", "fold:2", "paragraph", "fold:section"])
    compare(Fold.unfoldedIndex(f, 2), 2)
    compare(Fold.unfoldedIndex(f, 4), 5)
    compare(Fold.unfoldedIndex(f, 9), -1)
    compare(Fold.openRange(f, 2), [2, 3])
    compare(Fold.openRange(f, 4), [5, 7])
    compare(Fold.openRange(f, 3), [4, 4])
    compare(Fold.openRange(f, 9), [-1, -1])
    // Opening the section's heading shows it with its body as a run fold;
    // opening every index in the range shows everything.
    compare(shape(Fold.fold(r.blocks, { 5: true })), ["heading", "heading", "fold:2", "paragraph", "heading", "fold:2"])
    var open = {}
    for (var i = 5; i <= 7; i++) open[i] = true
    compare(shape(Fold.fold(r.blocks, open)), ["heading", "heading", "fold:2", "paragraph", "heading", "paragraph", "paragraph"])
  }
}
