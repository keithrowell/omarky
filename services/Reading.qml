pragma Singleton
import QtQuick
import Quickshell
import qs.Commons

// Reading typography: the families and the modular scale every block uses.
// Zoom scales this only, never the chrome (Style.font stays as it is).
Singleton {
  id: root

  property real zoom: 1.0

  readonly property string prose: "iA Writer Quattro S"
  readonly property string mono: "iA Writer Mono S"

  // Body size: the shell's rem root scaled up for long-form reading.
  readonly property real body: Math.round(Style.font.body * 1.2 * zoom)
  readonly property real lineHeight: 1.6
  readonly property real ratio: 1.25

  // Colours and families lib/inline.js bakes into rich text. Rich text
  // cannot blend alpha, so washes are flattened onto the page colour here.
  readonly property var tones: ({
    rev: Theme.revision,
    mono: mono,
    text: Theme.hex(Theme.text),
    link: Theme.hex(Theme.accent),
    codeText: Theme.hex(Theme.mix(Theme.text, Theme.accent, 0.12)),
    codeBg: Theme.hex(Theme.flat(Theme.fg, Theme.light ? 0.07 : 0.085))
  })

  function size(step) { return Math.round(body * Math.pow(ratio, step)) }
}
