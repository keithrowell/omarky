import QtQuick
import Quickshell
import qs.Commons
import qs.services

// One window per open file.
FloatingWindow {
  id: win
  property string path: ""
  readonly property string fileName: path ? path.split("/").pop() : ""
  readonly property Item grabRoot: page
  // Screenshot-only switches (tools/screenshot): outline, wide, find, ...
  property var shotOptions: ({})

  // Scrolls one screen for the screenshot driver; false at the end.
  function shotNextPage() { return view.pageDown() }

  title: fileName ? "OmaRead — " + fileName : "OmaRead"
  implicitWidth: 1100
  implicitHeight: 900
  color: Theme.bg

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
    }
  }
}
