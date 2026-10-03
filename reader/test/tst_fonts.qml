import QtQuick
import QtTest
import "../lib/fonts.js" as Fonts

// lib/fonts.js: requested families, and the fallback when one is missing.
TestCase {
  name: "Fonts"

  readonly property var installed: ["iA Writer Quattro S", "iA Writer Mono S", "IBM Plex Sans", "IBM Plex Mono"]

  function test_installed_family_is_used() {
    compare(Fonts.pick("IBM Plex Sans", installed, "iA Writer Quattro S"), "IBM Plex Sans")
    compare(Fonts.pick("  IBM Plex Mono ", installed, "iA Writer Mono S"), "IBM Plex Mono")
  }

  function test_case_is_ignored_and_installed_spelling_kept() {
    compare(Fonts.pick("ibm plex sans", installed, "x"), "IBM Plex Sans")
  }

  function test_missing_family_falls_back_to_default() {
    compare(Fonts.pick("Not A Real Font", installed, "iA Writer Quattro S"), "iA Writer Quattro S")
    compare(Fonts.pick("IBM Plex Sans", [], "iA Writer Quattro S"), "iA Writer Quattro S")
    compare(Fonts.pick("IBM Plex Sans", undefined, "iA Writer Quattro S"), "iA Writer Quattro S")
  }

  function test_empty_request_is_default() {
    compare(Fonts.pick("", installed, "iA Writer Quattro S"), "iA Writer Quattro S")
    compare(Fonts.pick(undefined, installed, "iA Writer Quattro S"), "iA Writer Quattro S")
  }

  function test_styled_heading() {
    compare(Fonts.pickStyled("IBM Plex Sans/SemiBold", installed, "iA Writer Quattro S", "Bold"),
            { family: "IBM Plex Sans", style: "SemiBold" })
    compare(Fonts.pickStyled("IBM Plex Sans", installed, "iA Writer Quattro S", "Bold"),
            { family: "IBM Plex Sans", style: "Bold" })
  }

  function test_styled_missing_family_drops_its_style() {
    compare(Fonts.pickStyled("Missing Serif/Black", installed, "iA Writer Quattro S", "Bold"),
            { family: "iA Writer Quattro S", style: "Bold" })
    compare(Fonts.pickStyled("", installed, "iA Writer Quattro S", "Bold"),
            { family: "iA Writer Quattro S", style: "Bold" })
  }
}
