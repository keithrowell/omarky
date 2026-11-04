# 0020 A click on a task box ticks it in the file

Date: 2026-11-04. Status: accepted. Amends 0018 ("OmaRead has no other way to change text").

## Decision

In OmarkyReader a click on a task list checkbox flips that item's box in the file: `[ ]` becomes `[x]` and back, one character on the line the item's marker is on. The whole file is written atomically, as the sheet writes it, and the page shows the new state when the file reloads, so it never draws a tick the file does not have.

## Why

Keith wanted to tick tasks while reading without opening the sheet or an editor. A box is the one place on the page where a click has a single, obvious meaning, so it does not turn the page into an editor the way editable blocks would (0018).

## Consequences

- Each list item carries `line`, the source line its marker is on (`lib/blocks.js`). `Blocks.toggleTask(src, line, done)` changes the box only when that line still is a task item; otherwise the reader says so and writes nothing.
- `MarkdownView.tasksEditable` turns it on; the view only raises `taskToggled`, and the host writes. The writer and other hosts leave it off and keep read-only boxes.
- Boxes are clickable when the page is the file on disk: not while the file is missing, not under the sheet, and in changes mode only when the newer side is Now. Removed items never take clicks.
- `reader/tools/check-tasks` checks it end to end.
