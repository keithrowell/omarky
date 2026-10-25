import QtQuick
import QtTest
import "../lib/diff/words.js" as Words

TestCase {
  name: "Words"

  function test_tokenize() {
    var t = Words.tokenize("We propose, a ten-week plan.")
    compare(t.map(function(x) { return x.t }), ["We", " ", "propose", ",", " ", "a", " ", "ten", "-", "week", " ", "plan", "."])
  }

  function test_tokenize_whitespace_keys() {
    var t = Words.tokenize("a\nb  c")
    compare(t.map(function(x) { return x.key }), ["a", " ", "b", " ", "c"])
    compare(t[1].t, "\n")
    compare(t[3].t, "  ")
    compare(Words.tokenize(""), [])
    compare(Words.tokenize(null), [])
  }

  function test_tokenize_unicode_words() {
    var t = Words.tokenize("naïve café’s résumé")
    compare(t.map(function(x) { return x.t }), ["naïve", " ", "café’s", " ", "résumé"])
  }

  function toks(s) { return s.split("").map(function(c) { return { t: c, key: c } }) }

  function test_diff_identical() {
    compare(Words.diff(toks("abc"), toks("abc")), [{ kind: "eq", a0: 0, a1: 3, b0: 0, b1: 3 }])
  }

  function test_diff_empty_sides() {
    compare(Words.diff([], []), [])
    compare(Words.diff(toks("ab"), []), [{ kind: "del", a0: 0, a1: 2, b0: 0, b1: 0 }])
    compare(Words.diff([], toks("ab")), [{ kind: "ins", a0: 0, a1: 0, b0: 0, b1: 2 }])
  }

  function test_diff_completely_different() {
    var d = Words.diff(toks("abc"), toks("xyz"))
    compare(d.map(function(o) { return o.kind }).sort(), ["del", "ins"])
    var del = d.filter(function(o) { return o.kind === "del" })[0], ins = d.filter(function(o) { return o.kind === "ins" })[0]
    compare([del.a0, del.a1], [0, 3])
    compare([ins.b0, ins.b1], [0, 3])
  }

  // The script must reproduce b from a: eq and ins ranges concatenated in
  // order spell b, eq and del ranges spell a, and eq ranges match by key.
  function checkScript(a, b) {
    var A = toks(a), B = toks(b), d = Words.diff(A, B)
    var sa = "", sb = ""
    var ea = 0, eb = 0
    for (var i = 0; i < d.length; i++) {
      var o = d[i]
      compare(o.a0, ea); compare(o.b0, eb)
      if (o.kind === "eq") {
        compare(a.slice(o.a0, o.a1), b.slice(o.b0, o.b1))
        sa += a.slice(o.a0, o.a1); sb += b.slice(o.b0, o.b1)
      } else if (o.kind === "del") { compare(o.b0, o.b1); sa += a.slice(o.a0, o.a1) }
      else { compare(o.a0, o.a1); sb += b.slice(o.b0, o.b1) }
      ea = o.a1; eb = o.b1
    }
    compare(ea, a.length); compare(eb, b.length)
    compare(sa, a); compare(sb, b)
    return d
  }

  function test_diff_scripts_are_consistent() {
    checkScript("abcabba", "cbabac")
    checkScript("a", "b")
    checkScript("ab", "ba")
    checkScript("abcd", "acxd")
    checkScript("xabc", "abc")
    checkScript("abc", "abcx")
    checkScript("aaaa", "aa")
    checkScript("mississippi", "missouri")
  }

  function test_diff_is_minimal() {
    // The classic Myers example: abcabba -> cbabac has edit distance 5.
    var d = Words.diff(toks("abcabba"), toks("cbabac"))
    var edits = 0
    d.forEach(function(o) { if (o.kind === "del") edits += o.a1 - o.a0; else if (o.kind === "ins") edits += o.b1 - o.b0 })
    compare(edits, 5)
  }

  function test_segments_reword() {
    var s = Words.segments("a twelve-week plan", "a ten-week plan")
    compare(s, [{ kind: "eq", text: "a " }, { kind: "del", text: "twelve" }, { kind: "ins", text: "ten" }, { kind: "eq", text: "-week plan" }])
  }

  function test_whitespace_is_not_a_change() {
    var s = Words.segments("one two\nthree", "one  two three")
    compare(s.length, 1)
    compare(s[0].kind, "eq")
    compare(s[0].text, "one  two three")
  }

  function test_insert_and_delete_at_ends() {
    compare(Words.segments("b c", "a b c"), [{ kind: "ins", text: "a " }, { kind: "eq", text: "b c" }])
    compare(Words.segments("a b c", "a b"), [{ kind: "eq", text: "a b" }, { kind: "del", text: " c" }])
  }

  function test_segments_empty_sides() {
    compare(Words.segments("", ""), [])
    compare(Words.segments("", "new words"), [{ kind: "ins", text: "new words" }])
    compare(Words.segments("old words", ""), [{ kind: "del", text: "old words" }])
  }

  function test_segments_identical() {
    compare(Words.segments("same here", "same here"), [{ kind: "eq", text: "same here" }])
  }

  function test_segments_completely_different() {
    compare(Words.segments("alpha beta", "gamma delta"), [{ kind: "del", text: "alpha beta" }, { kind: "ins", text: "gamma delta" }])
  }

  function test_segments_join_changes_across_spaces() {
    // Each side keeps its own spacing inside the change, so the del is a
    // slice of the old text and the ins a slice of the new.
    compare(Words.segments("the quick  brown fox", "a slow brown fox"),
            [{ kind: "del", text: "the quick" }, { kind: "ins", text: "a slow" }, { kind: "eq", text: " brown fox" }])
    compare(Words.segments("x alpha  beta y", "x gamma delta y"),
            [{ kind: "eq", text: "x " }, { kind: "del", text: "alpha  beta" }, { kind: "ins", text: "gamma delta" }, { kind: "eq", text: " y" }])
  }

  function test_similarity() {
    fuzzyCompare(Words.similarity("the cat sat", "the cat sat"), 1, 0.001)
    verify(Words.similarity("the cat sat on the mat", "the cat sat on a mat") > 0.7)
    verify(Words.similarity("alpha beta", "gamma delta") < 0.01)
    compare(Words.similarity("", ""), 1)
    compare(Words.similarity("", "words"), 0)
    compare(Words.similarity("Case", "case"), 1)
  }

  function test_diff_is_fast_on_long_similar_texts() {
    var words = []
    for (var i = 0; i < 20000; i++) words.push("w" + (i % 700))
    var a = words.join(" ")
    var bw = words.slice(); bw[5000] = "changed"; bw.splice(12000, 0, "extra")
    var b = bw.join(" ")
    var t0 = Date.now()
    var s = Words.segments(a, b)
    var ms = Date.now() - t0
    verify(ms < 500, "segments over 20k words took " + ms + " ms")
    compare(s.filter(function(x) { return x.kind === "del" }).length, 1)
    compare(s.filter(function(x) { return x.kind === "ins" }).length, 2)
  }
}
