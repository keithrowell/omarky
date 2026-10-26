# Changelog

One version for the suite since 0.6.0. Before that: 0.1.0 to 0.2.1 are the library's, 0.4.0 and
earlier are OmaRead's, and OmaRead 0.5.0 and OmaWriter 0.1.0 are in `docs/reader/CHANGELOG.md` and
`docs/writer/CHANGELOG.md`.

## 0.6.0 (2026-10-26)

- Omarky is the suite: OmaRead is OmarkyReader, OmaWriter is OmarkyWriter, and both live in this
  repository beside the library they share, with their histories. One command, `omarky`, with
  `read`, `changes`, `write` and `build`; one `ops/install`; one version. Window classes are
  `omarky-reader` and `omarky-writer`, state lives in `~/.local/state/omarky-reader` and
  `omarky-writer`, and the environment is `OMARKY_READER_*`, `OMARKY_WRITER_*` and `OMARKY_*`.
  The installer turns an earlier `omaread`, `omachanges` or `omawriter` into a shim and copies
  their state across once.

## 0.2.1 (2026-10-26)

- For OmaRead's block-editing sheet: the editor raises `submit` on Ctrl+Enter, its `topPad` and
  `bottomPad` can be set by the host, and `contentHeight` says how tall its text is. Paired and
  removed blocks from the diff engine carry `fromStart` and `fromEnd`, the older wording's lines.

## 0.2.0 (2026-10-26)

- The editor comes in from OmaWriter: `components/Editor.qml` (its five settings are properties
  the host binds), `Buffer`, `PopupMenu`, `lib/editing.js`, the native highlighter under `native/`
  as the `Omarky.Native` QML module, and `Omarky::Native`, the Ruby that builds it into an app's
  `build/`. The highlighter is optional: without the module on `QML_IMPORT_PATH` the editor runs
  as a plain `TextEdit`. `tools/test` builds the module and runs the highlighter suite against it.

## 0.1.0 (2026-10-26)

- Split from OmaRead 0.4.0: the renderer, the diff engine, the shared chrome, the launcher's
  Ruby (`Omarky::Instance`, `History`, `Resolver`, `Versions`), the tests and the samples, so
  OmaRead and OmaWriter both vendor one library and code can move between them.

## 0.4.0 (2026-10-26)

- Changes mode: OmaChanges, built on 25 October as its own app, is now part of OmaRead. When the
  file has check-ins in git, a branching chip in the header (or `V`) lists its versions as
  people and times; picking one compares the file as it is now with that version in the same
  column, the changes marked in the line. `N` and `P` step between changes, `F` folds everything
  unchanged, `Esc` goes back to reading. `omaread FILE --from danny`, `--to`, `--changes`,
  `--list`, `--resolve` and `--versions` on the command line; `omachanges` is an alias that
  implies `--changes`. The launcher is Ruby now (`/usr/bin/ruby`, standard library only), the
  diff engine lives in `lib/diff/`, and `tools/check-changes` drives the mode offscreen.
- `MarkdownView.changes` takes a prepared document with change marks: inserted runs sit on a wash
  in the theme's green, removed runs read faint under a strike in its red, a changed block says
  "reworded", "added" or "removed" in a pill in the margin, a block added or removed whole sits
  on a wash, and a `fold` block draws a "3 paragraphs unchanged" row or a dimmed heading.
  `Blocks.index()` indexes any block list and `Doc.adopt()` installs one.
- The outline marks the current section with shading alone; the accent bar beside it is gone.
  In changes mode it shows each section's change count at the right, with a small bar after it
  split green and red by the words added and removed in the section.
- A change tag whose word will not fit the margin (a narrow window, or the outline open in one)
  becomes a dot in the same tone, with the word in its tooltip.
- Two-finger scrolling travels as far as it does in Chromium (Helium), twelve times what Qt's
  Flickable gives a trackpad, and flings when the fingers lift, on Chromium's own curve. A mouse
  wheel notch moves 120 px, smoothed. The view's own wheel handling is off (docs/decisions/0011).
- Headings no longer carry a hairline underneath h1 and h2.
- Links keep their colour on a theme whose accent is the same as its text colour (Kanagawa):
  links, footnote numbers and the front matter link row then use the theme's blue.

## 0.3.2 (2026-10-04)

- Bare front matter: `key: value` lines at the top of a file with no `---` fences, ended by the
  first blank line (MultiMarkdown metadata, the shape static blogs use), is drawn as the same card
  as YAML front matter instead of a run-together paragraph. Two or more key lines are needed, so a
  one-line `Note: …` paragraph stays prose. A key with no value shows as a faint dash.

## 0.3.1 (2026-10-03)

- Fonts an app can set: prose, heading and code families, each from the environment
  (`OMAREAD_PROSE_FONT`, `OMAREAD_HEADING_FONT`, `OMAREAD_MONO_FONT`; `OMAREAD_CODE_FONT` still
  works) or from QML (`Reading.proseFamily`, `headingFamily`, `monoFamily`). A family that is not
  installed falls back to OmaRead's default. Defaults are unchanged, and the measure follows
  the prose font in use.
- MarkdownView: `baseUrl` can be a local directory, so a string read from a file resolves its
  images and links beside it; `keepPlace` keeps the reader's place when the string is the same
  document edited.

## 0.3.0 (2026-10-03)

- Image galleries: HTML that is nothing but `<img>` tags (optionally in `<p>`, `<div>`, `<center>`
  or `<a>`) now shows the images in centred rows that wrap, at their HTML height or width,
  instead of as source. Any other raw HTML is still shown literally (docs/decisions/0002).

## 0.2.0 (2026-10-03)

- MarkdownView: the renderer as a reusable component (Markdown string or file in, links out).
  Another Quickshell app can link OmaRead's directories into its own config and show Markdown
  with `MarkdownView` from `qs.components`; OmaRead's own window now uses it too.
- A document can be a string as well as a file (`Doc.text`); relative images and links resolve
  against a web `baseUrl` when one is given.

## 0.1.0 (2026-09-30)

First release.

- Renders Markdown with one native component per block: headings, paragraphs, lists and tasks,
  quotes, GitHub alerts, code with KSyntaxHighlighting, diffs, tables, rules, images, raw HTML,
  YAML front matter and footnotes.
- Follows the Omarchy theme live, including code colours generated from each theme.
- One process, one window per file; a second `omaread` call opens a new window over IPC.
- Outline with scroll-spy, reading-progress line, find, live reload that keeps your place,
  copy a block's Markdown, zoom, recent files, drag and drop.
