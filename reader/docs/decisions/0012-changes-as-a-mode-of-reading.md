# 0012 Changes is a mode of OmaRead, not an app

Date: 2026-10-26. Status: accepted.

## Decision

OmaChanges, the document diff reader built on 25 October 2026 as its own Quickshell app, is folded into OmaRead. A window that has a file with check-ins in git grows a branching chip in its header; picking a version there, or opening with `omaread FILE --from SPEC`, puts the same window into changes mode: the pill names the two ends, the column shows the newer text with the changes marked, `N`, `P` and `F` work, and `Esc` returns to reading at the same place. The launcher becomes Ruby and absorbs the OmaChanges command line. `omachanges` stays as a name for the same launcher, implying `--changes`. The OmaChanges repository is kept as history only.

## Why

The change marks already lived in OmaRead (`MarkdownView.changes`, the washes, tags and fold rows went upstream on the day OmaChanges was built), so the app that was left held the diff engine, the git resolver, and a second copy of OmaRead's window, header, keys, find, outline, help sheet and single-instance shell. About half of ChangesWindow was ReaderWindow line for line. Every renderer change needed a submodule move and a second commit before it could be seen. Reading a document and reading what changed in it are the same activity with one more control, and Keith's sketch of the merged app was a chip in the reader's toolbar that reveals the changes toolset.

OmaWriter stays its own app. An editor owns every key, and it brings a native build (CMake, Qt private headers, Sonnet) that the reader should not need. It should take OmaRead as a submodule rather than the copy it carries now, so its preview tracks the renderer and can show changes too.

## Consequences

- OmaRead depends on `/usr/bin/ruby` for its launcher and on `git` for changes mode. Both ship with Omarchy; git is only run when a window asks about versions.
- The window never runs git itself. It asks the launcher: `--versions` once per file (and again after each reload, debounced) and `--resolve SPEC` for a side. The launcher's path comes from `Quickshell.shellDir`, with `OMAREAD_BIN` as an override for tests.
- A target handed to the shell is `path[#anchor]`, or `path[#anchor]<TAB>FROM<TAB>TO` to open comparing.
- The outline marks the current section with shading alone, as the OmaChanges outline did; the accent bar is gone from plain reading too.
- Hyprland sees one window class, `omaread`, where there were two.
- The diff engine's tests join OmaRead's; the launcher's minitest suites run after them from `tools/test`. `tools/check-changes` replaces OmaChanges' `tools/check`.
