import QtQuick
import QtTest
import "../lib/diff/align.js" as Align

TestCase {
  name: "Align"
  function id(x) { return x }

  function test_lcs() {
    compare(Align.lcs(["a", "b", "c", "d"], ["a", "c", "x", "d"], id), [[0, 0], [2, 1], [3, 3]])
  }

  function test_lcs_edges() {
    compare(Align.lcs([], ["a"], id), [])
    compare(Align.lcs(["a"], [], id), [])
    compare(Align.lcs(["a", "b"], ["a", "b"], id), [[0, 0], [1, 1]])
    compare(Align.lcs(["a", "b"], ["x", "y"], id), [])
    compare(Align.lcs([{ k: "p" }, { k: "q" }], [{ k: "q" }], function(o) { return o.k }), [[1, 0]])
  }

  function test_pair_by_similarity_does_not_cross() {
    // a0 ~ b1 strongly, a1 ~ b0 weakly: only one pair survives.
    function sim(i, j) { return (i === 0 && j === 1) ? 0.9 : (i === 1 && j === 0) ? 0.6 : 0 }
    compare(Align.pairBySimilarity([0, 1], [0, 1], sim, 0.5), [[0, 1]])
  }

  function test_pair_by_similarity_respects_threshold_and_order() {
    function sim(i, j) { return i === j ? 0.7 : 0.55 }
    compare(Align.pairBySimilarity([0, 1, 2], [0, 1, 2], sim, 0.6), [[0, 0], [1, 1], [2, 2]])
    compare(Align.pairBySimilarity([0, 1], [0, 1], sim, 0.8), [])
    compare(Align.pairBySimilarity([], [0], sim, 0.1), [])
  }

  function test_plan() {
    var a = ["Intro", "The twelve-week plan has three stages", "Same", "Gone"]
    var b = ["Intro", "The ten-week plan has three stages", "New", "Same"]
    function sim(i, j) { return a[i].split(" ").filter(function(w) { return b[j].split(" ").indexOf(w) >= 0 }).length / Math.max(a[i].split(" ").length, b[j].split(" ").length) }
    var p = Align.plan(a, b, id, sim, 0.5)
    compare(p.pairs, [[0, 0, true], [1, 1, false], [2, 3, true]])
    compare(p.removed, [3])
    compare(p.added, [2])
  }

  function test_plan_similarity_stays_inside_gaps() {
    // a1 is similar to b3, but the exact match a2 = b1 sits between them,
    // so pairing them would cross; a1 is removed and b3 added instead.
    var a = ["x", "alpha beta", "same"]
    var b = ["x", "same", "other", "alpha beta gamma"]
    function sim(i, j) { return (i === 1 && j === 3) ? 0.9 : 0 }
    var p = Align.plan(a, b, id, sim, 0.5)
    compare(p.pairs, [[0, 0, true], [2, 1, true]])
    compare(p.removed, [1])
    compare(p.added, [2, 3])
  }

  function test_plan_empty_sides() {
    function zero() { return 0 }
    compare(Align.plan([], ["a", "b"], id, zero, 0.5), { pairs: [], removed: [], added: [0, 1] })
    compare(Align.plan(["a", "b"], [], id, zero, 0.5), { pairs: [], removed: [0, 1], added: [] })
    compare(Align.plan([], [], id, zero, 0.5), { pairs: [], removed: [], added: [] })
  }
}
