# 0013 Git stays behind the launcher

Date: 2026-10-25. Status: accepted.

## Decision

The window never runs git. The Ruby launcher resolves the two versions, reads their texts, and hands the window one JSON job: two texts, two labels (a person and a time), the file's history as people and times, and the shortcut chips. When the window needs another version later (a pick in the list), it runs `bin/omachanges FILE --resolve SPEC` and reads the same JSON shape from stdout.

## Reasons

The window's job is reading. Resolving "danny fri" or "sent" is text parsing over `git log`, which Ruby does in a few lines with tests over a scripted repository. QML could shell out to git itself, but then the spec grammar would live in two places, the tests would need an offscreen window, and every error path (no repository, no author, a date before the file existed) would need handling in both.

The boundary is also where the next version sources go. A Dropbox revision, a history the Oma apps keep for themselves, or a second file on disk each become another way for the launcher to produce the same JSON. The window does not change.

## Consequences

- The window starts after one process spawn and a JSON parse. On the sample history that is well under a second.
- A pick in the version list costs one `--resolve` call, around the time git takes to show one blob.
- The launcher runs on `/usr/bin/ruby` with the standard library only, as WebReader's handler does, so opening a document never depends on mise or on the directory it was opened from.
