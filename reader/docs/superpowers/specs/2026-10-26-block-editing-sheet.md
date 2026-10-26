# Editing a block from OmaRead

Date: 26 October 2026. Step 3 of three: the library split, the editor's move into Omarky, and this.

## Outcome

Reading a document and finding a sentence to fix, Keith presses `E` and the block under the mouse opens in a sheet over the page, in OmaWriter's editor, with the blocks before and after it shown faint for context. He types, presses Ctrl+Enter, and the file on disk has the change. The page reloads under the sheet as it does for any edit on disk, keeping its place. `Esc` closes the sheet without writing. OmaRead stays a reader: the sheet is the only way text changes, it edits one block or one section at a time, and it never holds a file open for writing.

Keith asked for this on 26 October: "for a small type-it-yourself edit, opening in another app feels jarring. What if we had a popup that just showed you the section and some surrounding text where OmaWriter's editing were available."

## What opens

| Key | Edits | Context shown |
|---|---|---|
| `E` | The block under the mouse, or the block holding the selection, or else the block at the top of the page | The block before and the block after, faint |
| `Shift+E` | The section: the nearest heading above (or the block itself when it is one) through to the line before the next heading of the same or a higher level | The heading before and the heading after, faint |

A block is edited as its source lines, `srcStart` to `srcEnd`, exactly as they are in the file. Front matter, a horizontal rule and the footnotes block edit the same way. In changes mode a fold row and a removed block cannot be edited, and the sheet refuses with a toast when the newer side of the comparison is a past version rather than the file ("Compare with Now to edit the file").

## The sheet

A card over a scrim, centred, as wide as the reading column plus the editor's hanging gutter, as tall as its text up to about two thirds of the window and scrolling inside after that. From the top: a line naming the file and the lines ("proposal.md, lines 41 to 47"), the faint block before, the editor, the faint block after, and a row of keys (`Esc` cancels, `Ctrl+Enter` saves). The context blocks are rendered by the library's own block components, dimmed, and clipped to a few lines each with a fade. Clicking the scrim does nothing; the sheet is modal and the keys close it.

The editor is the library's `Editor` with focus and typewriter off, spelling on, the reader's zoom, and small top and bottom padding (two new properties on `Editor`, since OmaWriter's half-window padding is for a page, not a card). The native highlighter paints it when OmaRead has built the module; without it the sheet still edits, plain. The editor's `command` signal drives the sheet: `save` and the new `submit` (Ctrl+Enter, added to the editor's key map) save, `escape` cancels. Every other command the editor raises (`find`, `preview`, `new`, `zoomIn` and so on) is ignored by the sheet.

In changes mode, when the block is reworded, a faint row above the editor shows the older wording as it was on the other side (the engine records `fromStart` and `fromEnd` on paired blocks) with a chip, "Use this", that puts that text in the editor. Saving then restores the old wording with one keystroke, which is the restore-block case from the design discussion without a launcher flag.

## Saving

Ctrl+Enter or Ctrl+S splices the editor's text in place of the block's lines and writes the whole file atomically through a `FileView`, keeping the file's final newline. Before writing, the sheet compares the document's source as it is now with the source it opened on. If the file changed meanwhile, nothing is written and the sheet shows a line, "The file changed while you were editing; copy your text and open it again," and stays open. A save that fails to write shows the error the same way.

After a successful write the sheet closes and a toast says "Saved". The reader's own watcher reloads the page, and `Changes` reloads the comparison when one is open, so the edit shows as a change at once.

`Esc` with unsaved text asks once: the key row changes to "Esc again to discard" for two seconds. `Esc` on unchanged text closes at once.

## Building the module

`bin/omaread` asks `Omarky::Native` for the module before starting the window and passes the import path through to `qs`, but does not require it: a reader must open on a machine with no cmake. `omaread --build` builds it alone, and `ops/install` calls that. The reader's dev tools (`tools/check-sheet`, `tools/screenshot`) take the same path.

## Tests and checks

| Where | What passes |
|---|---|
| Omarky `tst_changes.qml` | Paired blocks carry `fromStart` and `fromEnd` |
| Omarky `tools/test` | Everything, with the editor's `submit` command and padding properties |
| OmaRead `tools/check-sheet` | Offscreen: open a sample, `E` on a block, type, Ctrl+Enter, the file has the splice and the page reloaded; `Shift+E` opens a whole section; `Esc` discards; a file changed under the sheet is refused; in changes mode "Use this" restores the older wording; with and without the module; a clean log |
| OmaRead `tools/test` and `tools/check-changes` | Unchanged |
| OmaRead, by hand | The sheet on the questionnaire in changes mode, a real save, the comparison updating |

## Versions and records

OmaRead goes to 0.5.0. Omarky to 0.2.1 (the editor's `submit` and padding, the engine's `fromStart` and `fromEnd`). Decision 0015 in OmaRead records why editing is a sheet over one block and not an editor in the reader. The README gets an "Editing a block" section with one screenshot, and `?` lists the two keys.

## Out of scope

The line that hands an instruction to Claude (the next step; the sheet's layout leaves room under the editor for it), the summary banner and "explain this change", and the meaning-judgement fold level.
