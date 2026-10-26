//@ pragma AppId omarky-writer
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components
import qs.app

// OmarkyWriter — a Markdown editor for Omarchy.
//   omarky write [file.md …]   (or: OMARKY_WRITER_OPEN=/abs/file.md qs -p writer/ui/shell.qml)
//
// Single instance, OmarkyReader's way: the first copy holds a flock and writes
// its pid into the lock file; a later copy finds the lock taken, asks that
// pid over IPC to open its files in new windows, and exits. bin/omarky
// takes the same shortcut before even starting qs.
ShellRoot {
  id: shell

  // Touch the palette singleton so it starts following theme switches, and
  // start generating the preview's code-highlighting themes right away.
  readonly property color _palette: Theme.green
  readonly property bool _highlight: Highlight.ready
  readonly property bool _settings: Settings.loaded

  readonly property string lockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarky-writer/"
                                     + (Quickshell.env("OMARKY_WRITER_INSTANCE") || "omarky-writer") + ".lock"
  // One path per line.
  readonly property var requested: (Quickshell.env("OMARKY_WRITER_OPEN") || "").split("\n").filter(function(l) { return l.trim() !== "" })
  property bool primary: false
  property int nextId: 1

  // A file already open comes to the front instead of opening twice.
  // "path" or "path<TAB>end" (cursor at the end).
  function open(target) {
    var parts = String(target || "").split("\t")
    var p = parts[0], atEnd = parts[1] === "end"
    if (p) for (var i = 0; i < instances.count; i++) {
      var w = instances.objectAt(i)
      if (w && w.filePath === p) {
        focusTitle.command = ["sh", "-c",
          'a=$(hyprctl clients -j | jq -r --arg t "$1" \'.[] | select(.title == $t) | .address\' | head -1); ' +
          '[ -n "$a" ] && hyprctl dispatch "hl.dsp.focus({ window = \\"address:$a\\" })"', "sh", w.title]
        focusTitle.running = true
        if (atEnd) w.toEnd()
        return
      }
    }
    windows.append({ wid: nextId++, path: p, atEnd: atEnd })
  }

  Process { id: focusTitle }

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
    running: true
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
        if (shell.requested.length === 0) shell.open("")
        for (var i = 0; i < shell.requested.length; i++) shell.open(shell.requested[i])
      }
    }
    onExited: if (!shell.primary) handOff.running = true
  }

  // Another copy owns the windows: pass it our files, then leave.
  Process {
    id: handOff
    command: ["sh", "-c",
      'lock=$1; shift; pid=$(cat "$lock" 2>/dev/null); [ -n "$pid" ] || exit 1; ' +
      'if [ $# -eq 0 ]; then qs ipc --pid "$pid" call omarky-writer open ""; fi; ' +
      'for f in "$@"; do qs ipc --pid "$pid" call omarky-writer open "$f"; done',
      "sh", shell.lockPath].concat(shell.requested)
    onExited: {
      console.info("OmarkyWriter is already running; opened the file there.")
      Qt.quit()
    }
  }

  Instantiator {
    id: instances
    model: windows
    delegate: WriterWindow {
      required property int wid
      required property bool atEnd
      required path
      startAtEnd: atEnd
      onOpenFile: p => shell.open(p)
      onNewWindow: shell.open("")
      onClosed: shell.closeWindow(wid)
      onCloseRequested: { finish(); shell.closeWindow(wid) }
    }
  }

  // qs ipc --pid <pid> call omarky-writer <fn> [args]
  IpcHandler {
    target: "omarky-writer"
    enabled: shell.primary
    // "" opens a new untitled document.
    function open(target: string): void { shell.open(target) }
    function count(): int { return windows.count }

    // Dev hooks (tools/check). `n` is a window index,
    // -1 for the newest.
    function state(n: int): string { var w = shell.win(n); return w ? JSON.stringify(w.debugState()) : "{}" }
    function command(n: int, name: string): void { var w = shell.win(n); if (w) w.command(name) }
    function type(n: int, s: string): void { var w = shell.win(n); if (w) w.debugType(s) }
    function cursor(n: int, p: int): void { var w = shell.win(n); if (w) w.debugCursor(p) }
    function key(n: int, spec: string): void { var w = shell.win(n); if (w) w.debugKey(spec) }
    function text(n: int): string { var w = shell.win(n); return w ? w.debugText() : "" }
    function shot(n: int, path: string): void { var w = shell.win(n); if (w) w.grabRoot.grabToImage(function(r) { r.saveToFile(path) }) }
    function close(n: int): void { var w = shell.win(n); if (w) w.closeRequested() }
  }

  function win(n) {
    var i = n < 0 ? instances.count - 1 : n
    return i >= 0 && i < instances.count ? instances.objectAt(i) : null
  }
}
