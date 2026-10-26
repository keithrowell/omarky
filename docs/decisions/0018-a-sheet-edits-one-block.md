# 0015 Editing happens in a sheet over one block, and the file is written whole

Date: 2026-10-26. Status: accepted.

## Decision

`E` opens the block under the mouse (or `Shift+E` its section) in a card over the page, in the library's editor, with the neighbouring blocks faint around it. Ctrl+Enter splices the edited lines into the source the sheet opened on and writes the whole file atomically; the page then reloads from disk as it does for any other edit. The sheet refuses to write when the file changed while it was open. OmaRead has no other way to change text and never keeps a file open for writing.

## Why

Keith wanted small corrections without leaving the reader: "for a small type-it-yourself edit, opening in another app feels jarring." The earlier position, that the reader should not grow an inline editor, still holds for the page itself. Editable blocks in the reading column would make every block a text field, break selection and find, and turn the reader into a second editor with its own save and conflict rules. A sheet keeps the page as it is: the editor is OmaWriter's, borrowed from the library for one block at a time, and what the reader shows is still only what is on disk.

Writing the whole file rather than patching lines in place is what the editor's own `Buffer` does, and it is the only way to be atomic on a plain file. Comparing the source before writing is cheaper and clearer than a merge: the sheet is for a few lines, and a clash is rare enough that "copy your text and open it again" is the honest answer.

In changes mode the sheet shows the older wording of a reworded block with a "Use this" chip, because the engine already knows where that wording is (`fromStart`, `fromEnd`). That covers the restore-a-block case without a launcher flag.

## Consequences

- The editor comes with its native highlighter when the module is built; `bin/omaread` builds it when it can and opens without it otherwise, so a reader never fails to open for want of cmake. `tools/check-sheet --plain` keeps the plain path working.
- A save shows up in the reader as a reload, and in changes mode as the comparison re-running, with no special case.
- Keys inside the sheet are the editor's. Ctrl+Enter is the editor's new `submit` command; everything else the editor raises (`preview`, `find`, `new`) is ignored there.
- The line that hands an instruction to Claude is the next step and sits under the editor when it comes.
