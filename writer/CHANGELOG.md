# Changelog

## Unreleased

- OmaRead's renderer comes from [Omarky](https://github.com/keithrowell/omarky), the library OmaRead and
  OmaWriter share, as a submodule at `vendor/omarky` in place of the copy taken on 17 October. The
  launcher is Ruby on `Omarky::Instance`, with the native build and `--end` as before.

## 0.1.0 (22 Oct 2026)

- Live Markdown editor: faded marks, emphasis, code chips, links, headings on a modular scale, hanging heading, list and quote marks, task boxes, fenced code, front matter, tables, footnotes.
- Spelling in Australian English (Sonnet and Hunspell), suggestions on right-click.
- Focus mode, typewriter scrolling, three iA Writer fonts, zoom, live Omarchy theme.
- Preview with OmaRead's renderer, opened at the cursor's block.
- Autosave for named files; untitled drafts in ~/.local/state/omawriter/drafts; Ctrl+R for recent files and drafts.
- Smart lists (Enter continues, Tab indents), formatting keys, find.
- Reload in place when the file changes on disk, or a choice when there are unsaved edits.
