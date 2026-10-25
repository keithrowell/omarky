# 0014 Omarky, the library both apps vendor

Date: 2026-10-26. Status: accepted.

## Decision

The code OmaRead and OmaWriter share lives in a third repository, [Omarky](https://github.com/keithrowell/omarky), which neither app is. Both apps vendor it as a git submodule at `vendor/omarky` and link its directories into their Quickshell root (`ui/`), so the import names stay `qs.components`, `qs.services`, `qs.Commons` and `qs.Ui`. An app's own QML sits in `ui/app/` behind `qs.app`. The launcher's single-background-process logic is `Omarky::Instance`; each app's `bin/` is a few lines on it.

## Why

Until today the library was OmaRead's repository, which OmaWriter vendored. Code could flow one way only: for the reader to borrow the editor (the block editor in decision 0012's sequel), the editor would have had to move into the reader. Keith asked for shared libraries serving both apps so code can go both directions. A library in the middle makes both apps leaves, which is the same shape as his Ruby apps on the DaisyStack gem.

## Consequences

- OmaRead's root is `ui/`, like the other apps. The launcher exports `OMAREAD_BIN` so the window can run it; `Quickshell.shellDir` is one level below the repository.
- Images and other files the QML opens must sit inside `ui/` (a symlink will do): Quickshell blackholes paths that leave its root.
- `tools/test` in an app runs the library's suites first, so a moved submodule is checked in the app that uses it.
- Omarky has its own version. 0.1.0 is OmaRead 0.4.0's shared half.
