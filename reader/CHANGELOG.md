# Changelog

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
