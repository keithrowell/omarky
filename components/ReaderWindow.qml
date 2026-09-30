import QtQuick
import Quickshell
import qs.Commons
import qs.services

// One window per open file.
FloatingWindow {
  id: win
  property string path: ""
  property string anchor: ""
  readonly property string fileName: path ? path.split("/").pop() : ""
  readonly property string dir: path ? path.slice(0, path.lastIndexOf("/")) : ""
  readonly property Item grabRoot: page
  // Screenshot-only switches (tools/screenshot): outline, wide, find, ...
  property var shotOptions: ({})

  // Asks the shell to open another file in a new window.
  signal openFile(string path, string anchor)

  title: fileName ? "OmaRead — " + fileName : "OmaRead"
  implicitWidth: 1100
  implicitHeight: 900
  color: Theme.bg

  // Scrolls one screen for the screenshot driver; false at the end.
  function shotNextPage() { return view.pageDown() }

  // What blocks call back into: links, copying, resolving paths.
  QtObject {
    id: ctx

    function resolveUrl(src) {
      var s = String(src || "")
      if (/^(https?|file|data|qrc):/i.test(s)) return s
      if (s.charAt(0) === "~") s = Quickshell.env("HOME") + s.slice(1)
      if (s.charAt(0) !== "/") s = win.dir + "/" + s
      return "file://" + encodeURI(decodeURI(s))
    }

    function copyText(text, note) {
      Quickshell.clipboardText = String(text)
      toast.show(note || "Copied")
    }

    function copyAnchor(slug) {
      copyText(win.fileName + "#" + slug, "Copied " + win.fileName + "#" + slug)
    }

    // http(s) and mailto open with xdg-open; #anchors scroll; relative .md
    // files open in a new OmaRead window; other local files via xdg-open.
    function openLink(href) {
      var h = String(href || "")
      if (!h) return
      if (h.charAt(0) === "#") { view.scrollToAnchor(decodeURIComponent(h.slice(1))); return }
      if (/^(https?|mailto|ftp):/i.test(h)) { Quickshell.execDetached(["xdg-open", h]); return }
      var hash = h.indexOf("#")
      var target = hash >= 0 ? h.slice(0, hash) : h
      var frag = hash >= 0 ? decodeURIComponent(h.slice(hash + 1)) : ""
      target = decodeURI(target.replace(/^file:\/\//, ""))
      if (target.charAt(0) === "~") target = Quickshell.env("HOME") + target.slice(1)
      if (target.charAt(0) !== "/") target = win.dir + "/" + target
      if (/\.(md|markdown|mdown|mkd)$/i.test(target)) win.openFile(target, frag)
      else Quickshell.execDetached(["xdg-open", target])
    }
  }

  Doc { id: doc; path: win.path }

  Item {
    id: page
    anchors.fill: parent
    // Opaque base so grabs render exactly as on screen.
    Rectangle { anchors.fill: parent; color: Theme.bg }

    DocView {
      id: view
      anchors.fill: parent
      blocks: doc.blocks
      anchorMap: doc.anchorMap
      ctx: ctx
    }

    Toast { id: toast }
  }
}
