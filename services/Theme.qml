pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Named colours from the current Omarchy theme (colors.toml) on top of the
// shell's Color singleton, and the reading tiers derived from them. Follows
// theme switches live: the shell's own Color only reloads on shell IPC, so
// this watches theme.name and feeds Color the new files itself (the
// Factory's pattern). OMAREAD_THEME_DIR pins any theme directory instead.
Singleton {
  id: root

  readonly property string overrideDir: Quickshell.env("OMAREAD_THEME_DIR") || ""
  readonly property string themeDir: Color.currentThemePath
  property var named: ({})
  property string currentName: ""
  readonly property string name: overrideDir ? overrideDir.replace(/\/+$/, "").split("/").pop() : currentName
  readonly property bool light: named.mode ? named.mode === "light" : luminance(Color.background) > 0.5
  // Bumped after every (re)load so views can re-derive cached rich text.
  property int revision: 0

  readonly property color bg: Color.background
  readonly property color fg: Color.foreground
  readonly property color accent: Color.accent

  readonly property color green: named.green || named.color2 || Color.accent
  readonly property color red: named.red || named.color1 || Color.urgent
  readonly property color yellow: named.yellow || named.color3 || Color.accent
  readonly property color blue: named.blue || named.color4 || Color.accent
  readonly property color magenta: named.magenta || named.color5 || Color.accent
  readonly property color cyan: named.cyan || named.color6 || Color.accent
  readonly property color orange: named.orange || named.yellow || named.color3 || Color.urgent

  // Text tiers: foreground mixed toward the background, so they read the
  // same way in light and dark themes (Qt.darker would brighten nothing).
  readonly property color text: Color.foreground
  readonly property color strong: named.bright_foreground || Color.foreground
  readonly property color dim: mix(Color.foreground, Color.background, 0.34)
  readonly property color faint: mix(Color.foreground, Color.background, 0.58)
  readonly property color ghost: mix(Color.foreground, Color.background, 0.8)

  // Surfaces, as translucent washes of the foreground over the background so
  // every theme gets the same relative depth.
  readonly property color raised: Util.alpha(Color.foreground, light ? 0.045 : 0.04)
  readonly property color sunken: Util.alpha(light ? Color.foreground : "#000000", light ? 0.035 : 0.22)
  readonly property color card: Util.alpha(Color.foreground, 0.035)
  readonly property color hairline: Util.alpha(Color.foreground, light ? 0.14 : 0.12)
  readonly property color hairlineSoft: Util.alpha(Color.foreground, light ? 0.09 : 0.075)
  readonly property color selection: Util.alpha(Color.accent, light ? 0.22 : 0.3)
  readonly property color hover: Util.alpha(Color.foreground, 0.06)

  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }

  function luminance(c) {
    return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
  }

  // A colour flattened onto the page background: rich text cannot blend
  // alpha, so anything it paints must be opaque.
  function flat(c, a) {
    return mix(Color.background, c, a)
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
      Color.loadColors(text())
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
      if (primed) Color.loadShell(text())
      primed = true
    }
  }

  // `omarchy theme set` swaps current/theme, then rewrites theme.name.
  FileView {
    id: nameFile
    path: Color.stateHome + "/omarchy/current/theme.name"
    watchChanges: root.overrideDir === ""
    printErrors: false
    onLoaded: root.currentName = text().trim()
    onFileChanged: {
      reload()
      if (root.overrideDir) return
      colorsFile.reload()
      shellFile.reload()
      Style.scheduleRefresh()
    }
  }
}
