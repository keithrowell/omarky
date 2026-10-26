# 0016 The editor lives in the library, and its highlighter is optional

Date: 2026-10-26. Status: accepted.

## Decision

OmaWriter's editing surface (`Editor`, `Buffer`, `PopupMenu`, `lib/editing.js`) and its native highlighter (`native/`, the `Omarky.Native` module) are part of Omarky. The editor reads none of OmaWriter's settings: focus, typewriter, spelling, font and zoom are properties the host binds, and the key map still raises `command(name)` for the host to act on. `Editor.qml` does not import the native module. A one-type file beside it, `NativeHighlighter.qml`, does, and the editor creates it with `Qt.createComponent` only when that import succeeds. Without the module the editor is a plain `TextEdit` in the right font and measure, with no spelling items in its menu, and `Editor.highlighted` is false.

An app that wants the painted editor builds the module with `Omarky::Native` into its own `build/` and puts that on `QML_IMPORT_PATH`. OmaWriter requires it. OmaRead will ask for it but run without it.

## Why

Step 3 of the plan Keith agreed to is a modal sheet in OmaRead that edits one block with OmaWriter's editor. The library in the middle (decision 0014 in OmaRead) exists so that code can go that way. The editor had to stop depending on OmaWriter's `Settings` singleton, which is the app's state, and on an import that OmaRead cannot be sure of: an import that fails fails the whole file, and a reader must open a document on a machine without cmake or the Qt headers. `Qt.createComponent` reports a missing module as a status without logging a warning, so the plain path leaves a clean log.

## Consequences

- The library's `tools/test` builds the module into `build/` and runs `tst_highlighter.qml` against it. Without cmake it skips that suite and says so.
- The editor's `qs.*` imports resolve only inside a running shell, so the plain path is checked by an app: OmaWriter's `tools/check --plain` starts the shell with no import path.
- Each app builds its own copy of the module, in its `build/`, against its own Qt. Two apps on one machine build it twice; the build takes seconds and the alternative (a shared build directory inside the submodule) would tie the apps' versions together.
- OmaWriter's decisions 0001 and 0002 are here as 0014 and 0015.
