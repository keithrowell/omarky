//@ pragma AppId omaread
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components

// OmaRead — a Markdown reader for Omarchy.
//   bin/omaread [file.md …]   (or: OMAREAD_OPEN=/abs/file.md qs -p shell.qml)
//
// Single instance, the Factory's way: the first copy holds a flock and
// writes its pid into the lock file; a later copy finds the lock taken,
// asks that pid over IPC to open its files in new windows, and exits.
// bin/omaread takes the same shortcut before even starting qs.
ShellRoot {
  id: shell

  // Touch the palette singleton so it starts following theme switches, and
  // start generating syntax-highlighting themes right away.
  readonly property color _palette: Theme.green
  readonly property bool _highlight: Highlight.ready

  readonly property string shotSpec: Quickshell.env("OMAREAD_SHOT") || ""
  readonly property string lockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omaread/"
                                     + (Quickshell.env("OMAREAD_INSTANCE") || "omaread") + ".lock"
  // "path" or "path#anchor", one per line.
  readonly property var requested: (Quickshell.env("OMAREAD_OPEN") || "").split("\n").filter(function(l) { return l.trim() !== "" })
  property bool primary: false
  property int nextId: 1

  function splitTarget(target) {
    var t = String(target)
    var hash = t.lastIndexOf("#")
    // A '#' in a directory name is kept: only split when it follows the file.
    if (hash > t.lastIndexOf("/")) return { path: t.slice(0, hash), anchor: t.slice(hash + 1) }
    return { path: t, anchor: "" }
  }

  function open(path, anchor) {
    windows.append({ wid: nextId++, path: String(path || ""), anchor: String(anchor || "") })
  }

  function closeWindow(wid) {
    for (var i = 0; i < windows.count; i++) {
      if (windows.get(i).wid === wid) { windows.remove(i); break }
    }
    if (windows.count === 0) Qt.quit()
  }

  ListModel { id: windows }

  // Holds the lock for as long as this qs process lives. If the lock is
  // taken by a copy that has just died (its holder lingers half a second),
  // keeps trying for a few seconds rather than handing off to nobody.
  Process {
    running: shell.shotSpec === ""
    command: ["sh", "-c",
      'QS=$PPID; lock=$1; mkdir -p "$(dirname "$lock")"; ' +
      'for i in $(seq 40); do ' +
      '  flock -n "$lock" sh -c \'echo $0 > "$1"; echo LOCKED; while kill -0 $0 2>/dev/null; do sleep 0.5; done\' "$QS" "$lock" && exit 0; ' +
      '  pid=$(cat "$lock" 2>/dev/null); [ -n "$pid" ] && [ "$pid" != "$QS" ] && kill -0 "$pid" 2>/dev/null && exit 1; ' +
      '  sleep 0.1; ' +
      'done; exit 1',
      "sh", shell.lockPath]
    stdout: SplitParser {
      onRead: line => {
        if (line !== "LOCKED") return
        shell.primary = true
        if (shell.requested.length === 0) shell.open("", "")
        for (var i = 0; i < shell.requested.length; i++) {
          var t = shell.splitTarget(shell.requested[i])
          shell.open(t.path, t.anchor)
        }
      }
    }
    onExited: if (!shell.primary) handOff.running = true
  }

  // Another copy owns the windows: pass it our files, then leave.
  Process {
    id: handOff
    command: ["sh", "-c",
      'lock=$1; shift; pid=$(cat "$lock" 2>/dev/null); [ -n "$pid" ] || exit 1; ' +
      'if [ $# -eq 0 ]; then qs ipc --pid "$pid" call omaread open ""; fi; ' +
      'for f in "$@"; do qs ipc --pid "$pid" call omaread open "$f"; done',
      "sh", shell.lockPath].concat(shell.requested)
    onExited: {
      console.info("OmaRead is already running; opened the file there.")
      Qt.quit()
    }
  }

  Instantiator {
    id: instances
    model: windows
    delegate: ReaderWindow {
      required property int wid
      required property string anchor
      required path
      initialAnchor: anchor
      onOpenFile: (p, a) => shell.open(p, a)
      onClosed: shell.closeWindow(wid)
      onCloseRequested: shell.closeWindow(wid)
    }
  }

  // qs ipc --pid <pid> call omaread <fn> [args]
  IpcHandler {
    target: "omaread"
    enabled: shell.primary
    // "path" or "path#anchor"; "" opens an empty window.
    function open(target: string): void {
      var t = shell.splitTarget(target)
      shell.open(t.path, t.anchor)
    }
    function count(): int { return windows.count }

    // Dev hooks (manual checks, see docs/REPORT.md). `n` is a window index,
    // -1 for the newest.
    function state(n: int): string { var w = shell.win(n); return w ? JSON.stringify(w.debugState()) : "{}" }
    function key(n: int, spec: string): void { var w = shell.win(n); if (w) w.sendKey(spec) }
    function shot(n: int, path: string): void { var w = shell.win(n); if (w) w.grabRoot.grabToImage(function(r) { r.saveToFile(path) }) }
    function link(n: int, href: string): void { var w = shell.win(n); if (w) w.debugLink(href) }
    function hover(n: int, index: int): void { var w = shell.win(n); if (w) w.debugHover(index) }
    function bench(n: int): string { var w = shell.win(n); return w ? JSON.stringify(w.debugBench()) : "{}" }
    function close(n: int): void { var w = shell.win(n); if (w) w.closeRequested() }
  }

  function win(n) {
    var i = n < 0 ? instances.count - 1 : n
    return i >= 0 && i < instances.count ? instances.objectAt(i) : null
  }

  Component { id: readerComponent; ReaderWindow {} }

  LazyLoader {
    active: shell.shotSpec !== ""
    Shooter { specPath: shell.shotSpec; windowComponent: readerComponent }
  }
}
