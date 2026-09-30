# 0010 Window behaviour choices

**Find.** Every searchable piece of text (paragraph, heading, table cell, code or diff block)
gets a document-order id when the file is parsed (`stampPieces` in `lib/blocks.js`). Matches are
counted over those pieces, so the count covers blocks not yet built by the ListView, and a text
item knows it holds the current match by comparing ids. Matches are painted inside the rich text
itself; the current one is solid accent with page-coloured text.

**Live reload.** The reader stays on the same block, recognised by its source text, and falls
back to the nearest block by source line. A file that is deleted keeps its content on screen
under a banner and is polled every second until it returns, because editors often delete and
recreate files when they save.

**Reduced motion.** Omarchy has no reduced-motion setting. OmaRead treats Hyprland's
`animations:enabled = false` as one, and also honours `OMAREAD_REDUCED_MOTION=1`. All durations
go through `Reading.motion()`, which returns zero in that case.

**Opening files.** Ctrl+O uses Qt's `FileDialog`. With Omarchy's `QT_QPA_PLATFORMTHEME=gtk3` it is
the native GTK chooser (checked in a real window). No other picker is installed (no zenity or
kdialog), so there is no fallback to shell out to.

**Copy.** Text items do not take keyboard focus, so the keys always reach the window. The window
remembers which item holds a selection and copies that on Ctrl+C. Right-click copies a block's
Markdown source; Ctrl+Shift+C copies the block under the mouse; Ctrl+Shift+A copies the file.
The spec's "Copy all" has no key of its own in the spec, so it got Ctrl+Shift+A and a header
button.

**Extra keys.** `W` toggles the wide measure, `/` opens find, `n`/`N` step through matches, and
Home/End/PageUp/PageDown work as expected. None of them conflict with the keys in the spec.

**State.** Zoom and the 20 recent files live in `~/.local/state/omaread/`. Screenshot runs never
write there.
