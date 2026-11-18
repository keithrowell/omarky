pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What OmarkyReader remembers across launches, under ~/.local/state/omarky-reader:
//   settings.json  { zoom, autoZoom }
//   recent.json    [ "/abs/path.md", … ]  newest first, at most 20
// Screenshot runs (OMARKY_SHOT) neither read nor write it.
Singleton {
  id: root

  // Screenshot runs never write, and only read a state dir named for them.
  readonly property bool ephemeral: (Quickshell.env("OMARKY_SHOT") || "") !== ""
  readonly property bool readable: !ephemeral || (Quickshell.env("OMARKY_READER_STATE_DIR") || "") !== ""
  readonly property string dir: (Quickshell.env("OMARKY_READER_STATE_DIR")
    || (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarky-reader")
  property real zoom: 1.0
  // Auto zoom: the reading text grows until the column fills the window
  // (DocView.fitZoom), so the measure stays 68 characters at any width.
  // fitZoom is what the window in use last measured; it is never saved.
  // Setting a zoom by hand (setZoom) switches auto zoom off.
  property bool autoZoom: false
  property real fitZoom: 1.0
  readonly property real effective: autoZoom ? fitZoom : zoom
  readonly property real maxZoom: 6.0
  property var recent: []
  readonly property int maxRecent: 20

  function setZoom(z) {
    zoom = Math.round(Math.max(0.6, Math.min(maxZoom, z)) * 100) / 100
    autoZoom = false
    save()
  }

  function setAutoZoom(on) {
    autoZoom = !!on
    save()
  }

  function addRecent(path) {
    if (!path || ephemeral) return
    var list = recent.filter(function(p) { return p !== path })
    list.unshift(path)
    recent = list.slice(0, maxRecent)
    saveRecent()
  }

  function forget(path) {
    recent = recent.filter(function(p) { return p !== path })
    saveRecent()
  }

  function save() {
    if (ephemeral) return
    mkdir.running = true
    settingsFile.setText(JSON.stringify({ zoom: zoom, autoZoom: autoZoom }, null, 2) + "\n")
  }

  function saveRecent() {
    if (ephemeral) return
    mkdir.running = true
    recentFile.setText(JSON.stringify(recent, null, 2) + "\n")
  }

  Process { id: mkdir; command: ["mkdir", "-p", root.dir] }

  FileView {
    id: settingsFile
    path: root.readable ? root.dir + "/settings.json" : ""
    printErrors: false
    blockWrites: true
    onLoaded: {
      try {
        var s = JSON.parse(text())
        if (typeof s.zoom === "number" && isFinite(s.zoom)) root.zoom = Math.max(0.6, Math.min(root.maxZoom, s.zoom))
        if (typeof s.autoZoom === "boolean") root.autoZoom = s.autoZoom
      } catch (e) {
        console.warn("OmarkyReader: ignoring unreadable settings.json")
      }
    }
  }

  FileView {
    id: recentFile
    path: root.readable ? root.dir + "/recent.json" : ""
    printErrors: false
    blockWrites: true
    onLoaded: {
      try {
        var r = JSON.parse(text())
        if (r instanceof Array) root.recent = r.filter(function(p) { return typeof p === "string" }).slice(0, root.maxRecent)
      } catch (e) {
        console.warn("OmarkyReader: ignoring unreadable recent.json")
      }
    }
  }

  Component.onCompleted: if (!ephemeral) mkdir.running = true
}
