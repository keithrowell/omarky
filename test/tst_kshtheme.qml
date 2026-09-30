import QtQuick
import QtTest
import "../lib/kshtheme.js" as Ksh

TestCase {
  name: "KshTheme"

  function test_maps_palette_roles() {
    var t = Ksh.theme({ foreground: "#d4be98", background: "#282828", red: "#ea6962", green: "#a9b665",
                        yellow: "#d8a657", blue: "#7daea3", magenta: "#d3869b", cyan: "#89b482", orange: "#e1875c" },
                      "OmaRead gruvbox")
    compare(t.metadata.name, "OmaRead gruvbox")
    compare(t["text-styles"].Normal["text-color"], "#d4be98")
    compare(t["text-styles"].String["text-color"], "#a9b665")
    compare(t["text-styles"].Keyword["text-color"], "#d3869b")
    compare(t["text-styles"].Function["text-color"], "#7daea3")
    compare(t["text-styles"].DecVal["text-color"], "#e1875c")
    verify(t["text-styles"].Comment.italic)
    compare(t["editor-colors"].BackgroundColor, "#282828")
  }

  function test_missing_keys_fall_back() {
    var t = Ksh.theme({ color7: "#eeeeee", color0: "#000000", color4: "#0000ff" }, "x")
    compare(t["text-styles"].Normal["text-color"], "#eeeeee")
    compare(t["text-styles"].Function["text-color"], "#0000ff")
    compare(t["text-styles"].String["text-color"], "#0000ff", "no green: accent")
    var empty = Ksh.theme({}, "y")
    verify(/^#[0-9a-f]{6}$/.test(empty["text-styles"].Comment["text-color"]))
  }

  function test_names() {
    compare(Ksh.themeName("tokyo-night"), "OmaRead tokyo-night")
    compare(Ksh.fileName("my theme/x"), "omaread-my_theme_x.theme")
  }
}
