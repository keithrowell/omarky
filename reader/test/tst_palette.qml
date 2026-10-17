import QtQuick
import QtTest
import "../lib/palette.js" as Palette

// lib/palette.js: the link colour, and when the accent cannot be it.
TestCase {
  name: "Palette"

  function test_accent_is_the_link_colour() {
    compare(Palette.linkColor("#7aa2f7", "#a9b1d6", "#7aa2f7"), "#7aa2f7")
  }

  function test_accent_equal_to_text_falls_back_to_blue() {
    // Kanagawa: accent and foreground are the same colour.
    compare(Palette.linkColor("#dcd7ba", "#dcd7ba", "#7e9cd8"), "#7e9cd8")
  }

  function test_accent_a_hair_from_text_falls_back_to_blue() {
    compare(Palette.linkColor("#dcd7bb", "#dcd7ba", "#7e9cd8"), "#7e9cd8")
  }

  function test_a_subtly_tinted_accent_is_kept() {
    // firmitas-utilitas-venustas: a warm tan accent on a grey text, distance about 42.
    compare(Palette.linkColor("#d4bda2", "#afaaa2", "#d4bda2"), "#d4bda2")
  }

  function test_distance_is_euclidean_in_rgb() {
    compare(Palette.distance("#000000", "#ffffff"), Math.sqrt(3 * 255 * 255))
    compare(Palette.distance("#102030", "#102030"), 0)
  }

  function test_case_and_whitespace_do_not_matter() {
    compare(Palette.linkColor(" #DCD7BA ", "#dcd7ba", "#7E9CD8"), "#7e9cd8")
  }
}
