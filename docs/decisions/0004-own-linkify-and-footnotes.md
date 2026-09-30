# 0004 Own linkify matcher and footnote plugin

**Linkify.** The linkify-it bundled inside `vendor/markdown-it.js` loads under V4 but its
matcher never matches (`pretest()` is true, `test()` is always false), so `linkify: true` did
nothing. `lib/linkify.js` is a ~50-line object with the same interface (`pretest`, `test`,
`match`, `matchAtStart`) assigned to `md.linkify`. It links scheme URLs (http, https, ftp),
`www.` hosts and e-mail addresses, trims trailing punctuation and keeps balanced parentheses, as
GitHub does. Bare domains like `file.md` are deliberately not linked.

**Footnotes.** Rather than vendor markdown-it-footnote with a shim, `lib/footnote.js` is a
compact block rule for `[^label]:` definitions and an inline rule for `[^label]` references,
modelled on the plugin. `lib/blocks.js` collects the definitions into a single `footnotes` block
at the end, numbered in order of first citation; unreferenced notes follow.

Task lists, GFM alerts and front matter are small post-processors in `lib/blocks.js` and
`lib/frontmatter.js`, as the spec suggests.
