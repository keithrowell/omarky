# 0001 Flat block list in a ListView

`lib/blocks.js` turns markdown-it's token stream into one flat array of top-level blocks. Lists,
quotes, alerts and footnotes keep their children inside the block object (`items[].blocks`,
`blocks`), so the view is a single `ListView` with one delegate per top-level block and a
`Loader` choosing the component by `type`. Nested blocks reuse the same chooser recursively.

A `Flickable` + `Column` would build every delegate up front; `long.md` has ~1,100 top-level
blocks, most of them rich-text `TextEdit`s, which is far too slow to open in under a second.
The ListView only builds what is on screen plus a cache buffer. Parsing itself is cheap:
`long.md` (5,400 lines) builds in about 40 ms under V4.
