import QtQuick
import QtTest
import "../lib/blocks.js" as Blocks
import "../lib/inline.js" as Inline
import "../lib/diff/runs.js" as Runs

TestCase {
  name: "Runs"
  function runsOf(src) { return Blocks.build(src).blocks[0].runs }

  function test_slice_splits_runs() {
    var rs = runsOf("plain **bold** end")
    var s = Runs.slice(rs, 3, 9)        // plain is "plain bold end"; [3, 9) is "in bol"
    compare(Inline.plain(s), "in bol")
    compare(s.length, 2)
    verify(!s[0].b && s[1].b)
  }

  function test_slice_edges() {
    var rs = runsOf("plain **bold** end")
    compare(Inline.plain(Runs.slice(rs, 0, 14)), "plain bold end")
    compare(Inline.plain(Runs.slice(rs, 0, 99)), "plain bold end")
    compare(Runs.slice(rs, 5, 5), [])
    compare(Inline.plain(Runs.slice(rs, 6, 10)), "bold")
    compare(Runs.slice([], 0, 3), [])
  }

  function test_slice_keeps_run_flags() {
    var rs = runsOf("see [the link](http://x.test) here")
    var s = Runs.slice(rs, 4, 12)
    compare(Inline.plain(s), "the link")
    compare(s.length, 1)
    compare(s[0].href, "http://x.test")
  }

  function test_mark_reword() {
    var m = Runs.markRuns(runsOf("a twelve-week plan"), runsOf("a *ten*-week plan"))
    verify(m.changed)
    var del = m.runs.filter(function(r) { return r.del }), ins = m.runs.filter(function(r) { return r.ins })
    compare(Inline.plain(del), "twelve")
    compare(Inline.plain(ins), "ten")
    verify(ins[0].i)
    compare(Inline.plain(m.runs), "a twelveten-week plan")
  }

  function test_unchanged_is_not_changed() {
    var m = Runs.markRuns(runsOf("same text\nwrapped"), runsOf("same text wrapped"))
    verify(!m.changed)
    compare(Inline.plain(m.runs), "same text wrapped")
    verify(m.runs.every(function(r) { return !r.del && !r.ins }))
  }

  function test_mark_keeps_to_side_styles_on_shared_text() {
    var m = Runs.markRuns(runsOf("keep this"), runsOf("keep **this**"))
    verify(!m.changed)
    compare(m.runs.filter(function(r) { return r.b }).map(function(r) { return r.t }), ["this"])
  }

  function test_mark_del_slices_old_side_spacing() {
    // The deleted words carry the old side's spacing; the new side's words
    // around them come from the new runs.
    var m = Runs.markRuns(runsOf("x alpha  beta y"), runsOf("x gamma delta y"))
    compare(Inline.plain(m.runs.filter(function(r) { return r.del })), "alpha  beta")
    compare(Inline.plain(m.runs.filter(function(r) { return r.ins })), "gamma delta")
    compare(Inline.plain(m.runs.filter(function(r) { return !r.del && !r.ins })), "x  y")
  }

  function test_mark_empty_sides() {
    var m = Runs.markRuns([], runsOf("all new"))
    verify(m.changed)
    verify(m.runs.every(function(r) { return r.ins }))
    compare(Inline.plain(m.runs), "all new")
    var g = Runs.markRuns(runsOf("all gone"), [])
    verify(g.changed)
    verify(g.runs.every(function(r) { return r.del }))
    compare(Inline.plain(g.runs), "all gone")
  }

  function test_mark_all() {
    var rs = Runs.markAll(runsOf("gone **now**"), "del")
    verify(rs.every(function(r) { return r.del }))
    verify(rs[1].b)
    compare(Runs.markAll(null, "ins"), [])
  }
}
