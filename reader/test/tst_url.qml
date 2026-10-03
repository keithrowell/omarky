import QtQuick
import QtTest
import "../lib/url.js" as Url

// lib/url.js: references in a web page against the page's URL.
TestCase {
  name: "Url"

  readonly property string page: "https://example.com/blog/2026/post.html?p=1#top"

  function test_relative() {
    compare(Url.resolve(page, "img/a.png"), "https://example.com/blog/2026/img/a.png")
    compare(Url.resolve(page, "./a.png"), "https://example.com/blog/2026/a.png")
    compare(Url.resolve(page, "../a.png"), "https://example.com/blog/a.png")
    compare(Url.resolve(page, "../../../../a.png"), "https://example.com/a.png")
    compare(Url.resolve(page, "x/./y/../z.png?s=2#f"), "https://example.com/blog/2026/x/z.png?s=2#f")
    compare(Url.resolve(page, ".."), "https://example.com/blog/")
  }

  function test_query_and_fragment_only() {
    compare(Url.resolve(page, "?p=2"), "https://example.com/blog/2026/post.html?p=2")
    compare(Url.resolve(page, "#part"), "https://example.com/blog/2026/post.html?p=1#part")
  }

  function test_root_and_protocol_relative() {
    compare(Url.resolve(page, "/about"), "https://example.com/about")
    compare(Url.resolve(page, "//cdn.example.org/x.png"), "https://cdn.example.org/x.png")
    compare(Url.resolve("http://example.com", "a.png"), "http://example.com/a.png")
  }

  function test_absolute_and_no_base() {
    compare(Url.resolve(page, "mailto:a@b.c"), "mailto:a@b.c")
    compare(Url.resolve("", "a.png"), "")
    compare(Url.resolve("file:///home/x.md", "a.png"), "")
  }
}
