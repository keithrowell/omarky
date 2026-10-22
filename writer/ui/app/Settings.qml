pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What OmaWriter remembers across launches, under ~/.local/state/omawriter:
//   settings.json  { zoom, font, focus, typewriter, spell }
//   recent.json    [ "/abs/path.md", … ]  newest first, at most 20
//   drafts/        untitled documents, saved as you type
// OMAWRITER_STATE_DIR moves all of it (screenshots and checks use one).
Singleton {
  id: root

  readonly property string dir: Quickshell.env("OMAWRITER_STATE_DIR")
    || (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omawriter"
  readonly property string draftsDir: dir + "/drafts"

  property real zoom: 1.0
  // The editor's family; the preview keeps OmaRead's.
  property string font: "iA Writer Quattro S"
  readonly property var fonts: ["iA Writer Quattro S", "iA Writer Duospace", "iA Writer Mono S"]
  property bool focus: false
  property bool typewriter: false
  property bool spell: true
  property var recent: []
  readonly property int maxRecent: 20
  property bool loaded: false

  function set(key, value) {
    root[key] = value
    save()
  }

  function setZoom(z) { set("zoom", Math.round(Math.max(0.6, Math.min(2.2, z)) * 100) / 100) }

  function nextFont() {
    var i = fonts.indexOf(font)
    set("font", fonts[(i + 1) % fonts.length])
  }

  function addRecent(path) {
    if (!path || path.indexOf(draftsDir + "/") === 0) return
    var list = recent.filter(function(p) { return p !== path })
    list.unshift(path)
    recent = list.slice(0, maxRecent)
    mkdir.running = true
    recentFile.setText(JSON.stringify(recent, null, 2) + "\n")
  }

  // A fresh draft path; the file appears once something is typed.
  function newDraftPath() {
    var d = new Date()
    function p(n) { return (n < 10 ? "0" : "") + n }
    var stamp = d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds())
    return draftsDir + "/untitled-" + stamp + "-" + Math.floor(Math.random() * 1000) + ".md"
  }

  function isDraft(path) { return String(path).indexOf(draftsDir + "/") === 0 }

  function save() {
    if (!loaded) return
    mkdir.running = true
    settingsFile.setText(JSON.stringify({ zoom: zoom, font: font, focus: focus, typewriter: typewriter, spell: spell }, null, 2) + "\n")
  }

  Process { id: mkdir; command: ["mkdir", "-p", root.dir, root.draftsDir] }

  FileView {
    id: settingsFile
    path: root.dir + "/settings.json"
    printErrors: false
    blockLoading: true
    onLoaded: {
      try {
        var s = JSON.parse(text())
        if (typeof s.zoom === "number" && isFinite(s.zoom)) root.zoom = Math.max(0.6, Math.min(2.2, s.zoom))
        if (typeof s.font === "string" && root.fonts.indexOf(s.font) >= 0) root.font = s.font
        if (typeof s.focus === "boolean") root.focus = s.focus
        if (typeof s.typewriter === "boolean") root.typewriter = s.typewriter
        if (typeof s.spell === "boolean") root.spell = s.spell
      } catch (e) {
        console.warn("OmaWriter: ignoring unreadable settings.json")
      }
      root.loaded = true
    }
    onLoadFailed: root.loaded = true
  }

  FileView {
    id: recentFile
    path: root.dir + "/recent.json"
    printErrors: false
    onLoaded: {
      try {
        var r = JSON.parse(text())
        if (r instanceof Array) root.recent = r.filter(function(p) { return typeof p === "string" }).slice(0, root.maxRecent)
      } catch (e) {
        console.warn("OmaWriter: ignoring unreadable recent.json")
      }
    }
  }

  Component.onCompleted: mkdir.running = true
}
