import QtQuick
import QtTest
import "../lib/code.js" as Code

TestCase {
  name: "Code"
  function test_one_paragraph_per_line_and_blank_lines_kept() {
    var html = Code.toHtml("a < b\n\n  c", 20)
    compare(html.split("<p ").length - 1, 3)
    verify(html.indexOf("&lt;") > 0)
    verify(html.indexOf("&nbsp;") > 0)
    verify(html.indexOf("line-height:20px") > 0)
  }
  function test_find_matches_painted_across_lines() {
    var html = Code.toHtml("beta\nx beta beta", 20, { find: "BETA", findBg: "#111111", current: 2, currentBg: "#222222" })
    compare(html.split("#111111").length - 1, 2)
    compare(html.split("#222222").length - 1, 1)
    compare(Code.lineOfMatch("beta\nx beta beta", "beta", 2), 1)
    compare(Code.lineOfMatch("beta", "zzz", 0), -1)
    compare(Code.docPosOfMatch("ab\n\nx beta beta", "beta", 1), 2 + 1 + 1 + 1 + 7)
  }

  function test_gutter_counts() {
    compare(Code.gutter(12, 20).split("<p ").length - 1, 12)
  }
}
