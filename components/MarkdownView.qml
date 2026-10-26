import QtQuick
import Quickshell
import qs.services
import "../lib/blocks.js" as Blocks
import "../lib/url.js" as Url

// The renderer on its own: a Markdown file (`path`) or string (`markdown`)
// in, the reading column out. Owns the parsed document, the view, find and
// what blocks call back into; leaves windows, keys, the outline and toasts
// to the app around it. ReaderWindow is one such app.
//
//   MarkdownView {
//     markdown: article.text; baseUrl: article.url; externalLinks: true
//     onLinkActivated: url => open(url)
//   }
Item {
  id: root

  // File mode when set; otherwise `markdown` is rendered.
  property string path: ""
  property string markdown: ""
  // Where relative images and links resolve when there is no file: an
  // http(s) page URL, or a local directory ("/abs/dir" or "file:///abs/dir")
  // so a string read from a file still finds its images and sibling files.
  property string baseUrl: ""
  // With a string: a changed `markdown` is the same document edited, so the
  // reader keeps their place (as a file reload does) instead of starting at
  // the top. Set `markdown` to "" first to show a different document.
  property bool keepPlace: false
  // Shown in copied heading links: "name#slug".
  property string documentName: ""
  property bool wide: false
  // Web and mail links go to linkActivated instead of xdg-open.
  property bool externalLinks: false
  // A prepared document: { blocks, headings, anchors, pieces, lineCount,
  // source }, as OmaChanges' diff engine makes. Set, it replaces `path` and
  // `markdown`; a new object is a reload that keeps the reader's place.
  property var changes: null
  onChangesChanged: if (changes) mdDoc.adopt(changes)
  Component.onCompleted: if (changes && !mdDoc.loaded) mdDoc.adopt(changes)

  readonly property alias doc: mdDoc
  readonly property alias view: mdView
  readonly property alias ctx: mdCtx
  readonly property alias finder: mdFinder
  readonly property real progress: mdView.progress
  readonly property string dir: path ? path.slice(0, path.lastIndexOf("/")) : localBase
  readonly property string localBase: {
    var b = String(baseUrl || "")
    if (/^file:\/\//i.test(b)) b = decodeURI(b.slice(7))
    else if (b.charAt(0) !== "/") return ""
    return b.length > 1 ? b.replace(/\/+$/, "") : b
  }

  // A web or mail link, when externalLinks is set; also any relative link
  // in a string with neither path nor baseUrl, unchanged.
  signal linkActivated(string url)
  // Something was copied; the app shows it (a toast).
  signal notice(string text)
  // A link to another Markdown file.
  signal openFile(string path, string anchor)
  // A fold row (blocks/Fold.qml) was clicked; `index` is its block index.
  signal unfoldRequested(int index)

  // Fade the column in, as on open.
  function appear() { mdView.appear() }

  // A relative reference against baseUrl, or "" when there is no web base.
  function resolveWeb(s) { return Url.resolve(root.baseUrl, s) }

  // A new string is a new document, not a reload: back to the top, find
  // cleared, faded in. Files keep the reader's place across reloads.
  function freshDocument() {
    mdFinder.clear()
    mdView.positionViewAtBeginning()
    appear()
  }

  // ---- what blocks call back into: links, copying, resolving paths, find
  QtObject {
    id: mdCtx

    property Item selectionOwner: null
    readonly property QtObject finder: mdFinder
    // The margin left of the column, for tags that must fit in it.
    readonly property real gutter: mdView.gutter

    function resolveUrl(src) {
      var s = String(src || "")
      if (/^(https?|file|data|qrc):/i.test(s)) return s
      var web = root.resolveWeb(s)
      if (web) return web
      if (s.charAt(0) === "~") s = Quickshell.env("HOME") + s.slice(1)
      if (s.charAt(0) !== "/") s = root.dir + "/" + s
      return "file://" + encodeURI(decodeURI(s))
    }

    function copyText(text, note) {
      Quickshell.clipboardText = String(text)
      root.notice(note || "Copied")
    }

    function copyAnchor(slug) {
      copyText(root.documentName + "#" + slug, "Copied " + root.documentName + "#" + slug)
    }

    function copyBlock(index) {
      var b = mdDoc.blocks[index]
      if (!b) return
      copyText(mdDoc.sourceLines(b.srcStart, b.srcEnd), "Copied the block's Markdown")
    }

    // Only one text item keeps a selection at a time; Ctrl+C copies it.
    function claimSelection(item) {
      if (selectionOwner && selectionOwner !== item && selectionOwner.deselect) selectionOwner.deselect()
      selectionOwner = item
    }

    // http(s) and mailto open with xdg-open (or go to linkActivated);
    // #anchors scroll; relative .md files open in a new OmarkyReader window;
    // other local files via xdg-open. With a web baseUrl, relative links
    // are web links; with a local one they are files beside it, as for a
    // path; a string with neither hands them to linkActivated as they are.
    function openLink(href) {
      var h = String(href || "")
      if (!h) return
      if (h.charAt(0) === "#") { mdView.scrollToAnchor(decodeURIComponent(h.slice(1))); return }
      if (!/^[a-z][a-z0-9+.-]*:/i.test(h)) {
        var web = root.resolveWeb(h)
        if (web) h = web
        else if (!root.dir) { root.linkActivated(h); return }
      }
      if (/^(https?|mailto|ftp):/i.test(h)) {
        if (root.externalLinks) root.linkActivated(h)
        else Quickshell.execDetached(["xdg-open", h])
        return
      }
      var hash = h.indexOf("#")
      var target = hash >= 0 ? h.slice(0, hash) : h
      var frag = hash >= 0 ? decodeURIComponent(h.slice(hash + 1)) : ""
      target = decodeURI(target.replace(/^file:\/\//, ""))
      if (target === "" || target === root.path) { if (frag) mdView.scrollToAnchor(frag); return }
      if (target.charAt(0) === "~") target = Quickshell.env("HOME") + target.slice(1)
      if (target.charAt(0) !== "/") target = root.dir + "/" + target
      if (/\.(md|markdown|mdown|mkd|mdx)$/i.test(target)) root.openFile(target, frag)
      else Quickshell.execDetached(["xdg-open", target])
    }

    // A text item holding the current match reports where it is.
    function revealMatch(item, localY) { mdView.reveal(item, localY) }

    function unfold(index) { root.unfoldRequested(index) }
  }

  // ---- find: every match in document order; the current one by piece id
  QtObject {
    id: mdFinder
    property string query: ""
    property var matches: []
    property int current: -1
    readonly property int currentPid: current >= 0 && current < matches.length ? matches[current].pid : -1
    readonly property int currentK: current >= 0 && current < matches.length ? matches[current].k : -1

    function search(q) {
      query = q
      matches = Blocks.findAll({ pieces: mdDoc.pieces }, q)
      // Start from the first match at or below the top of the page.
      var top = mdView.topIndex, pick = matches.length ? 0 : -1
      for (var i = 0; i < matches.length; i++) if (matches[i].block >= top) { pick = i; break }
      go(pick)
    }

    function go(i) {
      if (!matches.length) { current = -1; return }
      current = (i + matches.length) % matches.length
      var m = matches[current]
      // Off-screen blocks are brought in first; the text item holding the
      // match then refines the position (ctx.revealMatch).
      var bottom = mdView.indexAt(mdView.width / 2, mdView.contentY + mdView.height - 1)
      if (!mdView.itemAtIndex(m.block) || m.block < mdView.topIndex || (bottom >= 0 && m.block > bottom))
        mdView.positionViewAtIndex(m.block, ListView.Center)
    }

    function clear() {
      query = ""
      matches = []
      current = -1
    }

    function refresh() {
      if (!query) return
      var c = current
      matches = Blocks.findAll({ pieces: mdDoc.pieces }, query)
      current = Math.min(c, matches.length - 1)
    }
  }

  Doc {
    id: mdDoc
    path: root.changes ? "" : root.path
    text: root.changes ? "" : root.markdown
    onAboutToReload: if (root.path || root.keepPlace || root.changes) mdView.captureAnchor()
    onReloaded: {
      if (!root.path && !root.keepPlace && !root.changes) { root.freshDocument(); return }
      mdView.restoreAnchor()
      mdFinder.refresh()
    }
    onLoadedChanged: if (loaded) { if (root.path) root.appear(); else root.freshDocument() }
  }

  DocView {
    id: mdView
    width: parent.width
    height: parent.height
    visible: (!!root.path || root.markdown !== "" || !!root.changes) && mdDoc.loaded
    blocks: mdDoc.blocks
    anchorMap: mdDoc.anchorMap
    lineCount: mdDoc.lineCount
    wide: root.wide
    ctx: mdCtx
    signature: b => b.type + "\n" + mdDoc.sourceLines(b.srcStart, b.srcEnd)
  }

  HighlightWarmup {
    langs: {
      var seen = {}, out = []
      function walk(list) {
        for (var i = 0; i < list.length; i++) {
          var b = list[i]
          if (b.type === "code" && b.lang && !seen[b.lang]) { seen[b.lang] = true; out.push(b.lang) }
          if (b.blocks) walk(b.blocks)
          if (b.items) b.items.forEach(function(it) { if (it.blocks) walk(it.blocks) })
        }
      }
      walk(mdDoc.blocks)
      return out
    }
  }
}
