# Omarky, the suite

Date: 26 October 2026. Keith's decisions: one repository at `keithrowell/omarky`, the apps named OmarkyReader and OmarkyWriter, a marketing site, and a README made from the same material.

## Outcome

Anyone on Omarchy can clone one repository, run one install script, and have a Markdown reader, a Markdown writer, and the reader's changes mode and block editing, with one command on PATH. The repository, the site and the README tell one story: what Omarky is for, what each app does, and how it is built. Keith's own machine keeps working through the rename: his skills, his capture script and his Hyprland bindings are updated with it.

## Layout

The library stays where it is, at the repository root, and the apps move in beside it. Nothing in the library's paths or imports changes.

```
omarky/
  components/ services/ lib/ Commons/ Ui/ vendor/ native/ launcher/ test/ samples/   the library, as now
  reader/      OmarkyReader: ui/shell.qml, ui/app/, launcher/, test/, tools/, ops/, docs/
  writer/      OmarkyWriter: the same shape
  bin/omarky   one launcher: omarky read FILE, omarky write FILE, omarky changes FILE, omarky build
  ops/install  one install for everything
  tools/test   the library's suites, then each app's
  docs/        decisions (one numbered series), specs, screenshots/reader, screenshots/writer
  site/        the marketing site, published by GitHub Pages
```

Each app's `ui/` links the library's directories two levels up (`reader/ui/components -> ../../components`), so the Quickshell import names stay `qs.components` and the rest. The apps' git histories come in with `git filter-repo --to-subdirectory-filter` and a merge, so blame survives.

## Names

| Thing | Name |
|---|---|
| The suite, the repository, the command | Omarky, `keithrowell/omarky`, `omarky` |
| The apps, in prose, titles and desktop entries | OmarkyReader, OmarkyWriter |
| Window classes and IPC targets | `omarky-reader`, `omarky-writer` |
| Window titles | `OmarkyReader — file.md`, `OmarkyWriter — file.md` |
| State | `~/.local/state/omarky-reader`, `~/.local/state/omarky-writer`; code themes in `~/.local/share/omarky/ksh` |
| Environment | `OMARKY_READER_*` and `OMARKY_WRITER_*` for the apps (`_OPEN`, `_INSTANCE`, `_STATE_DIR`, `_BIN`); `OMARKY_*` for the library (`THEME_DIR`, `SHOT`, `NOW`, the fonts, `REDUCED_MOTION`, `NO_KSH`) |
| Desktop entries and icons | `omarky-reader.desktop`, `omarky-writer.desktop`, the same names for the SVGs |
| Version | One `VERSION` for the suite, starting at 0.6.0 (the reader's line continued) |

The subcommands:

```
omarky read FILE.md[#anchor] …          OmarkyReader
omarky read FILE --from danny [--to X]  the file compared with a version
omarky changes FILE                     the same as read --changes
omarky write [FILE.md …] [--end]        OmarkyWriter
omarky build                            the editor's native highlighter
omarky --version, omarky --help
```

`ops/install` puts `omarky` on PATH, and where it finds the old `omaread`, `omawriter` or `omachanges` links it replaces them with one-line shims onto the subcommands, so nothing on Keith's machine stops working. The old desktop entries and icons are removed and the new ones added. The `text/markdown` default is kept as it was.

## The site and the README

Both are written from one outline, the README as the GitHub-flavoured form and the site as a static page in `site/` with its own CSS, published by a Pages workflow:

1. What Omarky is: Markdown tools for Omarchy, built to read and write prose on the machine as it is, following the theme.
2. The philosophy: the file is the document (no database, no export); reading is a first-class act, not a preview; the apps take the theme and the fonts from Omarchy; one background process per app, a window per file, nothing to configure; versions are people and times, never commits; editing from the reader stays small.
3. OmarkyReader: the reading column, the outline, find, themes, links between files, changes mode, the edit sheet. Screenshots.
4. OmarkyWriter: live Markdown, hanging marks, focus and typewriter, spelling, preview, drafts. Screenshots.
5. How it works: Quickshell and QML, one library both apps share, one native module, Ruby for the launcher with git behind it, the decisions log.
6. Install and use.

The screenshots are rendered by the apps' own tools under Omarchy themes and framed as the reader's README shots are now. The site gets larger hero renders. Every screenshot is of a sample document in the repository, never a private file.

## Tests and checks

| Where | What passes |
|---|---|
| `tools/test` at the root | The library's suites, the reader's CLI suite, the writer's |
| `reader/tools/check-changes`, `check-sheet`, `check-sheet --plain` | As before, under the new names |
| `writer/tools/check`, `check --plain` | As before |
| By hand | `omarky read` and `omarky write` open windows with the new classes and titles, a second launch hands over, `omaread` and `omawriter` shims still work, the Hyprland Super+S binding saves in the writer, `capture-note` opens the writer at the end |

## Out of scope

A domain for the site (Pages at `keithrowell.github.io/omarky` first), packaging for the Omarchy plugin marketplace or AUR, and the Claude instruction line in the edit sheet.
