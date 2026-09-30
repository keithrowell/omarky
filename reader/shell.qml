//@ pragma AppId omaread
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components

// OmaRead — a Markdown reader for Omarchy.
//   bin/omaread [file.md]      (or: qs -p shell.qml, with OMAREAD_OPEN=file.md)
ShellRoot {
  id: shell

  // Touch the palette singleton so it starts following theme switches.
  readonly property color _palette: Theme.green
  readonly property string shotSpec: Quickshell.env("OMAREAD_SHOT") || ""

  Component { id: readerComponent; ReaderWindow {} }

  LazyLoader {
    active: shell.shotSpec !== ""
    Shooter { specPath: shell.shotSpec; windowComponent: readerComponent }
  }

  LazyLoader {
    active: shell.shotSpec === ""
    ReaderWindow { path: Quickshell.env("OMAREAD_OPEN") || "" }
  }
}
