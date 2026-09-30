# Changelog

## 0.1.0 (2026-09-30)

First release.

- Renders Markdown with one native component per block: headings, paragraphs, lists and tasks,
  quotes, GitHub alerts, code with KSyntaxHighlighting, diffs, tables, rules, images, raw HTML,
  YAML front matter and footnotes.
- Follows the Omarchy theme live, including code colours generated from each theme.
- One process, one window per file; a second `omaread` call opens a new window over IPC.
- Outline with scroll-spy, reading-progress line, find, live reload that keeps your place,
  copy a block's Markdown, zoom, recent files, drag and drop.
