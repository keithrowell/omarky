pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../lib/fonts.js" as Fonts

// Reading typography: the families and the modular scale every block uses.
// Zoom scales this only, never the chrome (Style.font stays as it is).
Singleton {
  id: root

  readonly property real zoom: Prefs.zoom

  // The reading families. Each can be asked for by the environment or by
  // an app embedding MarkdownView (Reading.proseFamily = "IBM Plex Sans");
  // the environment wins, so it stays a switch for comparing candidates
  // (docs/decisions/0005). A family that is not installed falls back to the
  // default, never to whatever Qt would substitute (lib/fonts.js).
  //   OMAREAD_PROSE_FONT    prose, tables, lists (the measure follows it)
  //   OMAREAD_HEADING_FONT  headings, "Family/Style"
  //   OMAREAD_MONO_FONT     code and labels (OMAREAD_CODE_FONT still works)
  property string proseFamily: ""
  property string headingFamily: ""
  property string monoFamily: ""

  readonly property string defaultProse: "iA Writer Quattro S"
  readonly property string defaultHeading: "iA Writer Quattro S/Bold"
  readonly property string defaultMono: "iA Writer Mono S"

  // Installed families, read once; refreshFonts() re-reads them after a
  // font is installed while the app runs.
  property var families: Qt.fontFamilies()
  function refreshFonts() { families = Qt.fontFamilies() }

  readonly property string prose: Fonts.pick(Quickshell.env("OMAREAD_PROSE_FONT") || proseFamily, families, defaultProse)
  readonly property string mono: Fonts.pick(Quickshell.env("OMAREAD_MONO_FONT") || Quickshell.env("OMAREAD_CODE_FONT") || monoFamily,
                                            families, defaultMono)
  readonly property var headingFont: {
    var d = defaultHeading.split("/")
    return Fonts.pickStyled(Quickshell.env("OMAREAD_HEADING_FONT") || headingFamily || defaultHeading, families, d[0], d[1])
  }
  readonly property string heading: headingFont.family
  readonly property string headingStyle: headingFont.style

  // Body size: the shell's rem root scaled up for long-form reading.
  readonly property real body: Math.round(Style.font.body * 1.2 * zoom)
  readonly property real lineHeight: 1.6
  // Chrome inside the page (badges, buttons) stays at UI size; zoom only
  // scales reading text.
  readonly property real chrome: Style.font.body
  readonly property real chromeSmall: Style.font.caption
  // Code: a touch smaller than prose, a little tighter leading.
  readonly property real codeSize: Math.round(body * 0.84)
  readonly property real codeLeading: 1.5

  // Motion: durations collapse to zero under reduced motion, which is
  // OMAREAD_REDUCED_MOTION=1 or Hyprland's animations switched off (Omarchy
  // has no separate setting).
  readonly property bool reducedMotion: Quickshell.env("OMAREAD_REDUCED_MOTION") === "1" || !hyprAnimations
  property bool hyprAnimations: true
  function motion(ms) { return reducedMotion ? 0 : ms }
  readonly property real ratio: 1.25

  // Colours and families lib/inline.js bakes into rich text. Rich text
  // cannot blend alpha, so washes are flattened onto the page colour here.
  readonly property var tones: ({
    rev: Theme.revision,
    mono: mono,
    text: Theme.hex(Theme.text),
    strong: Theme.hex(Theme.strong),
    dim: Theme.hex(Theme.dim),
    link: Theme.hex(Theme.accent),
    codeText: Theme.hex(Theme.mix(Theme.text, Theme.accent, 0.12)),
    codeBg: Theme.hex(Theme.flat(Theme.fg, Theme.light ? 0.07 : 0.085)),
    codeSize: Math.round(body * 0.86),
    rawText: Theme.hex(Theme.faint),
    findBg: Theme.hex(Theme.flat(Theme.accent, Theme.light ? 0.22 : 0.3)),
    currentBg: Theme.hex(Theme.accent),
    currentText: Theme.hex(Theme.bg)
  })

  // Vertical rhythm: the gap above a block, in pixels, given the block
  // before it. Headings bind to what follows them, not what precedes.
  function gapBefore(prev, cur) {
    if (!prev) return 0
    var em = body
    if (cur.type === "heading") {
      if (prev.type === "hr") return Math.round(em * 1.5)   // the rule already marks the break
      if (prev.type === "heading" && cur.level > prev.level)
        return Math.round(em * (prev.level <= 2 ? 1.25 : 0.7))   // clear of the hairline
      return Math.round(em * [0, 2.6, 2.2, 1.7, 1.4, 1.3, 1.3][cur.level])
    }
    var framed = { code: 1, diff: 1, table: 1, alert: 1, image: 1, gallery: 1, quote: 1, frontmatter: 1 }
    if (prev.type === "heading") return Math.round(em * (prev.level <= 2 || framed[cur.type] ? 0.75 : 0.5))
    if (prev.type === "frontmatter") return Math.round(em * 2.2)
    if (cur.type === "hr" || prev.type === "hr") return Math.round(em * 1.9)
    if (cur.type === "footnotes") return Math.round(em * 2.6)
    if (framed[cur.type] || framed[prev.type]) return Math.round(em * 1.25)
    return Math.round(em * 0.9)
  }

  Process {
    running: true
    command: ["hyprctl", "-j", "getoption", "animations:enabled"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.hyprAnimations = JSON.parse(text).int !== 0 } catch (e) { root.hyprAnimations = true }
      }
    }
  }

  function size(step) { return Math.round(body * Math.pow(ratio, step)) }
}
