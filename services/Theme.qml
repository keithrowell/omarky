pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../lib/palette.js" as Palette

// Named colours from the current Omarchy theme (colors.toml) on top of the
// shell's Color singleton, and the reading tiers derived from them. Follows
// theme switches live: the shell's own Color only reloads on shell IPC, so
// this watches theme.name and feeds Color the new files itself (the
// Factory's pattern). OMARKY_THEME_DIR pins any theme directory instead.
Singleton {
  id: root

  readonly property string overrideDir: Quickshell.env("OMARKY_THEME_DIR") || ""
  readonly property string themeDir: ShellColor.currentThemePath
  property var named: ({})
  property string currentName: ""
  // With an override, a theme.name beside the directory (a fake
  // current/theme + current/theme.name, as `omarchy theme set` makes) is
  // followed too; otherwise the directory's own name is the theme's name.
  readonly property string name: currentName || (overrideDir ? overrideDir.replace(/\/+$/, "").split("/").pop() : "")
  readonly property bool light: named.mode ? named.mode === "light" : luminance(ShellColor.background) > 0.5
  // Bumped after every (re)load so views can re-derive cached rich text.
  property int revision: 0

  readonly property color bg: ShellColor.background
  readonly property color fg: ShellColor.foreground
  readonly property color accent: ShellColor.accent

  readonly property color green: named.green || named.color2 || ShellColor.accent
  readonly property color red: named.red || named.color1 || ShellColor.urgent
  readonly property color yellow: named.yellow || named.color3 || ShellColor.accent
  readonly property color blue: named.blue || named.color4 || ShellColor.accent
  readonly property color magenta: named.magenta || named.color5 || ShellColor.accent
  readonly property color cyan: named.cyan || named.color6 || ShellColor.accent
  readonly property color orange: named.orange || named.yellow || named.color3 || ShellColor.urgent
  // Links: the accent, unless the theme's accent is its text colour, then blue.
  readonly property color link: Palette.linkColor(hex(ShellColor.accent), hex(ShellColor.foreground), hex(blue))

  // Text tiers: foreground mixed toward the background, so they read the
  // same way in light and dark themes (Qt.darker would brighten nothing).
  readonly property color text: ShellColor.foreground
  readonly property color strong: named.bright_foreground || ShellColor.foreground
  readonly property color dim: mix(ShellColor.foreground, ShellColor.background, 0.34)
  readonly property color faint: mix(ShellColor.foreground, ShellColor.background, 0.58)
  readonly property color ghost: mix(ShellColor.foreground, ShellColor.background, 0.8)

  // Surfaces, as translucent washes of the foreground over the background so
  // every theme gets the same relative depth.
  readonly property color raised: Util.alpha(ShellColor.foreground, light ? 0.045 : 0.04)
  readonly property color sunken: Util.alpha(light ? ShellColor.foreground : "#000000", light ? 0.035 : 0.22)
  // Code panels sit one step below the page: the theme's own darker
  // background when it names one.
  readonly property color panel: named.dark_background ? named.dark_background : Qt.darker(ShellColor.background, light ? 1.04 : 1.2)
  readonly property color card: Util.alpha(ShellColor.foreground, 0.035)
  readonly property color hairline: Util.alpha(ShellColor.foreground, light ? 0.14 : 0.12)
  readonly property color hairlineSoft: Util.alpha(ShellColor.foreground, light ? 0.09 : 0.075)
  readonly property color selection: Util.alpha(ShellColor.accent, light ? 0.22 : 0.3)
  readonly property color chipFill: Util.alpha(ShellColor.foreground, light ? 0.07 : 0.085)
  readonly property color chipEdge: Util.alpha(ShellColor.foreground, light ? 0.07 : 0.06)
  readonly property color hover: Util.alpha(ShellColor.foreground, 0.06)

  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }

  function luminance(c) {
    return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
  }

  // A colour flattened onto the page background: rich text cannot blend
  // alpha, so anything it paints must be opaque.
  function flat(c, a) {
    return mix(ShellColor.background, c, a)
  }

  function hex(c) {
    function h(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }

  function parseNamed(raw) {
    var parsed = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["'](#[0-9A-Fa-f]{6,8})["']/)
      if (m) parsed[m[1]] = m[2]
      var mode = lines[i].match(/^\s*mode\s*=\s*["'](light|dark)["']/)
      if (mode) parsed.mode = mode[1]
    }
    return parsed
  }

  FileView {
    id: colorsFile
    path: root.themeDir + "/colors.toml"
    printErrors: false
    onLoaded: {
      root.named = root.parseNamed(text())
      ShellColor.loadColors(text())
      root.revision++
    }
  }

  FileView {
    id: shellFile
    path: root.themeDir + "/shell.toml"
    printErrors: false
    // First load is Color's own; only feed it again after a switch.
    property bool primed: false
    onLoaded: {
      if (primed) ShellColor.loadShell(text())
      primed = true
    }
  }

  // `omarchy theme set` swaps current/theme, then rewrites theme.name.
  FileView {
    id: nameFile
    path: root.overrideDir ? root.overrideDir.replace(/\/+$/, "") + ".name" : ShellColor.stateHome + "/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.currentName = text().trim()
    onFileChanged: {
      reload()
      colorsFile.reload()
      shellFile.reload()
      Style.scheduleRefresh()
    }
  }
}
