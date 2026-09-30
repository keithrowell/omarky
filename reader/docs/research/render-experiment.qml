import QtQuick
import "w_markdown_it_min.js" as MDI
Window {
  width: 1300; height: 900; visible: true; color: "#282828"
  property string src: "# The Heading\n\nA paragraph with *emphasis*, **strong**, `inline code` and a [link](https://x.org). It runs long enough to wrap onto a second line so we can see line height and measure.\n\n## Second level\n\n> A blockquote that says something wise.\n\n- one\n- two\n  - nested\n- [x] done task\n\n| Col A | Col B |\n|-------|------:|\n| 1 | 22 |\n| 333 | 4 |\n\n```python\ndef f(x):\n    return x * 2\n```\n\n---\n\n![img](missing.png)\n"
  Row {
    spacing: 20; x: 20; y: 20
    TextEdit {
      width: 600; readOnly: true; wrapMode: TextEdit.Wrap
      textFormat: TextEdit.MarkdownText; text: src
      color: "#ebdbb2"; font.family: "iA Writer Quattro S"; font.pixelSize: 17
    }
    TextEdit {
      width: 600; readOnly: true; wrapMode: TextEdit.Wrap
      textFormat: TextEdit.RichText
      color: "#ebdbb2"; font.family: "iA Writer Quattro S"; font.pixelSize: 17
      text: "<html><head><style>" +
        "p { line-height: 150%; margin-bottom: 14px; } h1 { color: #fabd2f; font-size: 30px; margin-bottom: 16px; } h2 { color: #83a598; font-size: 22px; }" +
        "code { font-family: 'iA Writer Mono S'; background-color: #3c3836; color: #fe8019; } pre { font-family: 'iA Writer Mono S'; background-color: #1d2021; padding: 12px; }" +
        "blockquote { color: #a89984; margin-left: 20px; font-style: italic; } a { color: #83a598; text-decoration: none; } table { border-collapse: collapse; } th { background-color: #3c3836; } td, th { padding: 6px; border: 1px solid #504945; }" +
        "</style></head><body>" + MDI.get()({linkify:true, typographer:true}).render(src) + "</body></html>"
    }
  }
  Timer { interval: 800; running: true; onTriggered: contentItem.grabToImage(function(r) { r.saveToFile("render.png"); Qt.quit() }) }
}
