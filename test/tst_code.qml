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
  function test_gutter_counts() {
    compare(Code.gutter(12, 20).split("<p ").length - 1, 12)
  }
}
