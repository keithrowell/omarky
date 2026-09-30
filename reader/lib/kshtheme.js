.pragma library

// Omarchy colors.toml -> a KSyntaxHighlighting theme (JSON), so code is
// coloured from the same palette as the rest of the page (decision 0006).
//
// named: the parsed colors.toml ({ foreground, background, red, … }).
// name:  the KSH theme name to write into the metadata.

function hexToRgb(h) {
  var m = String(h || "").match(/^#?([0-9a-fA-F]{6})/)
  if (!m) return null
  var n = parseInt(m[1], 16)
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}

function rgbToHex(c) {
  function h(v) { var s = Math.max(0, Math.min(255, Math.round(v))).toString(16); return s.length < 2 ? "0" + s : s }
  return "#" + h(c[0]) + h(c[1]) + h(c[2])
}

function mix(a, b, t) {
  var x = hexToRgb(a), y = hexToRgb(b)
  if (!x || !y) return a || b
  return rgbToHex([x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t])
}

function palette(named) {
  var n = named || {}
  var fg = n.foreground || n.color7 || "#cccccc"
  var bg = n.background || n.color0 || "#101010"
  var accent = n.accent || n.blue || n.color4 || fg
  function pick() {
    for (var i = 0; i < arguments.length; i++) if (arguments[i]) return arguments[i]
    return accent
  }
  return {
    fg: fg, bg: bg, accent: accent,
    dim: mix(fg, bg, 0.3),
    faint: mix(fg, bg, 0.52),
    red: pick(n.red, n.color1),
    green: pick(n.green, n.color2),
    yellow: pick(n.yellow, n.color3),
    blue: pick(n.blue, n.color4),
    magenta: pick(n.magenta, n.color5),
    cyan: pick(n.cyan, n.color6),
    orange: pick(n.orange, n.yellow, n.color3)
  }
}

function style(color, extra) {
  var s = { "text-color": color, "selected-text-color": color }
  for (var k in extra || {}) s[k] = extra[k]
  return s
}

function theme(named, name) {
  var p = palette(named)
  var styles = {
    Normal: style(p.fg),
    Keyword: style(p.magenta),
    ControlFlow: style(p.magenta),
    Function: style(p.blue),
    Variable: style(p.fg),
    Operator: style(p.dim),
    BuiltIn: style(p.cyan),
    Extension: style(p.blue),
    Preprocessor: style(p.orange),
    Attribute: style(p.yellow),
    Char: style(p.orange),
    SpecialChar: style(p.orange),
    String: style(p.green),
    VerbatimString: style(p.green),
    SpecialString: style(p.cyan),
    Import: style(p.magenta),
    DataType: style(p.yellow),
    DecVal: style(p.orange),
    BaseN: style(p.orange),
    Float: style(p.orange),
    Constant: style(p.orange),
    Comment: style(p.faint, { italic: true }),
    Documentation: style(p.faint, { italic: true }),
    Annotation: style(p.dim),
    CommentVar: style(p.dim, { italic: true }),
    RegionMarker: style(p.faint),
    Information: style(p.blue),
    Warning: style(p.yellow),
    Alert: style(p.red, { bold: true }),
    Others: style(p.cyan),
    Error: style(p.red, { underline: true })
  }
  return {
    metadata: { name: name, revision: 1, license: "MIT", "read-only": true },
    "text-styles": styles,
    "editor-colors": {
      BackgroundColor: p.bg, CodeFolding: p.faint, BracketMatching: p.faint, CurrentLine: p.bg,
      IconBorder: p.bg, IndentationLine: p.faint, LineNumbers: p.faint, CurrentLineNumber: p.dim,
      MarkBookmark: p.blue, MarkBreakpointActive: p.red, MarkBreakpointReached: p.yellow,
      MarkBreakpointDisabled: p.magenta, MarkExecution: p.faint, MarkWarning: p.yellow, MarkError: p.red,
      ModifiedLines: p.yellow, ReplaceHighlight: p.green, SavedLines: p.green, SearchHighlight: p.yellow,
      TextSelection: mix(p.accent, p.bg, 0.7), Separator: p.faint, SpellChecking: p.red,
      TabMarker: p.faint, TemplateBackground: p.bg, TemplatePlaceholder: p.faint,
      TemplateFocusedPlaceholder: p.dim, TemplateReadOnlyPlaceholder: p.faint, WordWrapMarker: p.faint
    },
    "custom-styles": {}
  }
}

// The KSH theme name OmaRead uses for an Omarchy theme directory name.
function themeName(omarchyName) { return "OmaRead " + omarchyName }

// A safe file name for that theme.
function fileName(omarchyName) { return "omaread-" + String(omarchyName).replace(/[^A-Za-z0-9_.-]/g, "_") + ".theme" }
