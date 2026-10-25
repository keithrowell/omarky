# Changelog

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
  In changes mode it shows each section's change count at the right.
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
