pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../lib/kshtheme.js" as Ksh

// Syntax-highlighting setup (decision 0006).
//
// KSyntaxHighlighting reads themes only from disk, once, when its Repository
// first loads, and QML cannot ask it to reload. So at startup this writes a
// KSH theme generated from every Omarchy theme's colors.toml into
// ~/.local/share/omaread/ksh (which bin/omaread puts on XDG_DATA_DIRS), and
// only then lets code blocks load the highlighter. A live theme switch just
// picks another pre-generated theme; a theme KSH never saw falls back to
// KSH's own light or dark default.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string dataDir: home + "/.local/share/omaread/ksh"
  readonly property string themesDir: dataDir + "/org.kde.syntax-highlighting/themes"
  // The generated themes are only visible when the launcher set this up.
  readonly property bool themesVisible: (Quickshell.env("XDG_DATA_DIRS") || "").split(":").indexOf(dataDir) >= 0
  // org.kde.syntaxhighlighting is present (package `syntax-highlighting`).
  property bool moduleAvailable: false
  // Code blocks wait for this before loading the highlighter.
  property bool ready: false
  property var generated: ({})
  // KSH theme to use for the current Omarchy theme, "" for the fallback.
  readonly property string themeName: themesVisible && generated[Theme.name] ? Ksh.themeName(Theme.name) : ""

  // Markdown info strings that are not KSH definition names or extensions.
  readonly property var aliases: ({
    sh: "Bash", shell: "Bash", zsh: "Zsh", console: "Bash", bash: "Bash", fish: "Fish",
    js: "JavaScript", javascript: "JavaScript", mjs: "JavaScript", jsx: "JavaScript React (JSX)",
    ts: "TypeScript", typescript: "TypeScript", tsx: "TypeScript React (TSX)",
    py: "Python", python: "Python", rb: "Ruby", ruby: "Ruby", rs: "Rust", rust: "Rust",
    go: "Go", golang: "Go", yml: "YAML", yaml: "YAML", toml: "TOML", json: "JSON", jsonc: "JSON",
    md: "Markdown", markdown: "Markdown", html: "HTML", xml: "XML", svg: "XML", css: "CSS",
    scss: "SCSS", sql: "SQL", psql: "SQL (PostgreSQL)", postgres: "SQL (PostgreSQL)",
    c: "C", h: "C", cpp: "C++", "c++": "C++", cc: "C++", hpp: "C++", java: "Java", kt: "Kotlin",
    kotlin: "Kotlin", swift: "Swift", lua: "Lua", qml: "QML", nix: "Nix", dockerfile: "Dockerfile",
    docker: "Dockerfile", make: "Makefile", makefile: "Makefile", ini: "INI Files", conf: "INI Files",
    erb: "Ruby/Rails/RHTML", php: "PHP/PHP", perl: "Perl", pl: "Perl", elixir: "Elixir", ex: "Elixir",
    hs: "Haskell", haskell: "Haskell", cs: "C#", csharp: "C#", zig: "Zig", vim: "Vim Script",
    diff: "Diff", patch: "Diff", graphql: "GraphQL", proto: "Protobuf", r: "R Script",
    ps1: "PowerShell", powershell: "PowerShell", tex: "LaTeX", latex: "LaTeX", math: "LaTeX"
  })

  function definitionName(lang) {
    var l = String(lang || "").toLowerCase()
    return aliases[l] || lang || ""
  }

  function start() {
    // OMAREAD_NO_KSH=1 behaves as if the package were missing (for checks).
    if (Quickshell.env("OMAREAD_NO_KSH") === "1") { ready = true; return }
    probe.running = true
  }

  // Is the QML module installed? Look where Qt looks, quietly: a failed
  // import would put an error in the log.
  Process {
    id: probe
    command: ["sh", "-c",
      'for d in $(echo "$QML_IMPORT_PATH:$QML2_IMPORT_PATH" | tr ":" " ") /usr/lib/qt6/qml /usr/lib64/qt6/qml; do ' +
      '[ -f "$d/org/kde/syntaxhighlighting/qmldir" ] && { echo yes; exit 0; }; done; echo no']
    stdout: StdioCollector {
      onStreamFinished: {
        root.moduleAvailable = text.trim() === "yes"
        if (root.moduleAvailable && root.themesVisible) collect.running = true
        else root.ready = true
      }
    }
  }

  // Every Omarchy theme's colors.toml, plus an OMAREAD_THEME_DIR override.
  Process {
    id: collect
    command: ["sh", "-c",
      'for d in "$HOME/.local/share/omarchy/themes"/* "$HOME/.config/omarchy/themes"/* "$1"; do ' +
      '[ -f "$d/colors.toml" ] || continue; echo "@@THEME $(basename "$d")"; cat "$d/colors.toml"; echo; done',
      "sh", Quickshell.env("OMAREAD_THEME_DIR") || "/nonexistent"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = text.split(/^@@THEME /m)
        var args = [root.themesDir]
        var made = {}
        for (var i = 0; i < parts.length; i++) {
          var nl = parts[i].indexOf("\n")
          if (nl < 0) continue
          var name = parts[i].slice(0, nl).trim()
          if (!name) continue
          var named = Theme.parseNamed(parts[i].slice(nl + 1))
          args.push(Ksh.fileName(name), JSON.stringify(Ksh.theme(named, Ksh.themeName(name)), null, 1))
          made[name] = true
        }
        root.pending = made
        write.command = ["sh", "-c",
          // Atomic (temp + rename) and only when changed: another OmaRead
          // starting at the same moment may be reading these files.
          'd=$1; shift; mkdir -p "$d" || exit 1; while [ $# -gt 1 ]; do t="$d/.$1.$$"; printf "%s\\n" "$2" > "$t" && ' +
          '{ if cmp -s "$t" "$d/$1"; then rm -f "$t"; else mv -f "$t" "$d/$1"; fi; }; shift 2; done',
          "sh"].concat(args)
        write.running = true
      }
    }
  }

  property var pending: ({})

  Process {
    id: write
    onExited: code => {
      if (code === 0) root.generated = root.pending
      else console.warn("OmaRead: could not write KSH themes to " + root.themesDir)
      root.ready = true
    }
  }

  Component.onCompleted: start()
}
