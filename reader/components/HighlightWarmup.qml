import QtQuick
import qs.services

// KSyntaxHighlighting compiles a language's rules the first time it
// highlights with it (up to ~80 ms). Rather than pay that as a code block
// scrolls into view, a hidden highlighter runs through the document's
// languages just after it opens, one per tick.
Item {
  id: root
  property var langs: []
  property int next: 0
  visible: false

  onLangsChanged: { next = 0; if (loader.item) tick.restart() }

  TextEdit { id: sample; text: "a = 1\n# note\n\"text\"" }

  Loader {
    id: loader
    active: Highlight.ready && Highlight.moduleAvailable && root.langs.length > 0
    source: "CodeHighlighter.qml"
    onLoaded: { item.target = sample; tick.restart() }
  }

  Timer {
    id: tick
    interval: 40
    repeat: true
    onTriggered: {
      if (!loader.item || root.next >= root.langs.length) { stop(); return }
      loader.item.lang = root.langs[root.next++]
    }
  }
}
