import QtQuick
import Quickshell
import Quickshell.Io

// One document on disk. Loads once, writes atomically, and watches the
// file: a change that isn't ours arrives as `changedOnDisk(text)` for the
// window to take or refuse. A path that doesn't exist yet is an empty
// document that appears on the first save.
Item {
  id: root

  property string path: ""
  // The file's text as we last read or wrote it.
  property string savedText: ""
  property bool loaded: false
  property bool exists: false
  property string error: ""

  signal opened(string text)
  signal changedOnDisk(string text)
  signal savedOk()

  function save(text) {
    if (!path) return
    savedText = text
    error = ""
    file.setText(text)
  }

  // Delete the file (an emptied draft).
  function remove() {
    if (path && exists) rm.running = true
  }

  Process { id: rm; command: ["rm", "-f", "--", root.path]; onExited: root.exists = false }

  FileView {
    id: file
    path: root.path
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onLoaded: {
      var t = text()
      root.exists = true
      if (!root.loaded) {
        root.loaded = true
        root.savedText = t
        root.opened(t)
      } else if (t !== root.savedText) {
        root.changedOnDisk(t)
      }
    }
    onLoadFailed: {
      if (!root.loaded) {
        root.loaded = true
        root.exists = false
        root.opened("")
      }
    }
    onFileChanged: debounce.restart()
    onSaved: { root.exists = true; root.savedOk() }
    onSaveFailed: err => { root.error = "Could not save: " + err }
  }

  Timer { id: debounce; interval: 150; onTriggered: file.reload() }
}
