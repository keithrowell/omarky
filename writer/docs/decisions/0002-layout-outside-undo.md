# 0002 Line layout is set outside the undo history

Status: accepted, 22 Oct 2026.

## Decision

The highlighter sets each line's block format (line height, hanging indent) with the document's undo recording switched off for that one change. It reaches the private `QTextDocumentPrivate::undoEnabled` flag through the explicit-instantiation access rule, and touches nothing else private.

## Why

The first version recorded layout changes like edits. Typing `- ` turned the line into a list item, and its new indent went into the undo history as a step of its own. Ctrl+Z then undid the indent, the highlighter saw a list item without one and set it again, and undo could never get past it. `tst_highlighter.qml` caught this (`test_typing_a_list_then_undo`).

Joining the layout change to the user's typing step does not work. `joinPreviousEditBlock` only joins an edit block, and typing in a TextEdit is not one, so the layout still became its own step. The public switch, `QTextDocument::setUndoRedoEnabled(false)`, clears the whole history, so it is only usable when a file has just been loaded.

## Consequences

Layout is presentation, so undo and redo only ever move text, and the test above passes in both directions. The cost is the private header. It pins the build to one Qt version, so the launcher stores the Qt version it built against in `build/qt-version` and rebuilds when `omarchy update` brings a new Qt. If a future Qt renames the flag, the build fails loudly rather than misbehaving. The fallback then is layout without hanging indents: set the line height once after loading, with undo off, and drop the per-line margins.
