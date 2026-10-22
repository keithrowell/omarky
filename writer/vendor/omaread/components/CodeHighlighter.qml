import QtQuick
import org.kde.syntaxhighlighting
import qs.services

// KSyntaxHighlighting on one code TextEdit. Loaded through a Loader only
// when the module is present (services/Highlight.qml), so a missing
// package leaves plain monospace code, never an error.
Item {
  id: root
  property Item target: null
  property string lang: ""

  readonly property var def: {
    var name = Highlight.definitionName(lang)
    var d = name ? Repository.definitionForName(name) : null
    // Then as a file extension ("rb", "tsx"); only for things that look like
    // one, since the first such lookup compiles every definition's globs.
    if ((!d || !d.name) && /^[A-Za-z0-9+#]{1,8}$/.test(lang)) d = Repository.definitionForFileName("file." + String(lang).toLowerCase())
    return d && d.name ? d : null
  }
  readonly property var theme: {
    var t = Highlight.themeName ? Repository.theme(Highlight.themeName) : null
    if (t && t.name) return t
    return Repository.defaultTheme(Theme.light ? Repository.LightTheme : Repository.DarkTheme)
  }

  SyntaxHighlighter {
    textEdit: root.def ? root.target : null
    definition: root.def ? root.def : ""
    theme: root.theme
  }
}
