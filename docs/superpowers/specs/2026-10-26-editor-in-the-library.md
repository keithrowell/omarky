# The editor moves into Omarky

Date: 26 October 2026. Step 2 of three: the library split (done), this, then OmaRead's block-editing sheet.

## Outcome

OmaWriter's editing surface becomes part of Omarky, so OmaRead can put it inside a modal sheet in step 3 and OmaWriter keeps using it unchanged. After this step OmaWriter's own code is its window, its settings, its help sheet and its launcher. Everything that edits text lives in the library and is tested there.

## What moves

| From OmaWriter | To Omarky | Change on the way |
|---|---|---|
| `ui/app/Editor.qml` | `components/Editor.qml` | Settings bindings become properties with defaults; the highlighter loads optionally |
| `ui/app/editing.js` | `lib/editing.js` | None |
| `ui/app/Buffer.qml` | `components/Buffer.qml` | None |
| `ui/app/PopupMenu.qml` | `components/PopupMenu.qml` | None |
| `native/` | `native/` | QML module `OmaWriter.Native` becomes `Omarky.Native`, plugin `omarkynative`, define `OMARKY_SONNET` |
| `ui/test/tst_editing.qml`, `tst_highlighter.qml` | `test/` | Import paths |
| the native build in `bin/omawriter` | `launcher/omarky/native.rb` | A class both launchers call |
| `docs/decisions/0001`, `0002` | `docs/decisions/0014`, `0015` | Copied, with the move noted; OmaWriter's copies point here |

Settings, the help sheet, the window and the launcher stay in OmaWriter. They are the app.

## The editor's interface

The editor stops reading OmaWriter's `Settings` singleton. The five things it read become properties the host binds:

```
Editor {
  focusMode: Settings.focus        // default false
  typewriter: Settings.typewriter  // default false
  spellCheck: Settings.spell       // default true
  family: Settings.font            // default "iA Writer Quattro S"
  zoom: Settings.zoom              // default 1.0
}
```

Everything else about the editor stays as it is: `text`, `textEdit`, `apply`, `selectRange`, `follow`, `cursorLine`, `handleKey`, the `command(name)` and `contextMenu(x, y, items)` signals, scrolling, the caret, the context menu. The key map stays in the editor and the host decides what each command does, which is how OmaRead's sheet will take `save` and `escape` without the editor knowing it is in a sheet.

## The highlighter is optional

An import that fails fails the whole QML file, so `Editor.qml` no longer imports the native module itself. A small `NativeHighlighter.qml` beside it does, and the editor loads that through a `Loader`. When the module is missing (OmaRead without a build, a machine without cmake) the loader reports an error, the editor runs as a plain `TextEdit` with the right font and measure, and the spelling items leave the context menu. `Editor.highlighter` is the highlighter or null, and `Editor.highlighted` says which.

The library's `tools/test` builds the module into `build/` when cmake is present and runs the highlighter suite with it. The editor itself imports Quickshell's `qs.*` modules, which only resolve inside a running shell, so the plain editor is checked by an app: OmaWriter's `tools/check --plain` starts the shell with no import path and confirms typing, the list keys and autosave still work and the log is clean.

## The native build in Ruby

`Omarky::Native` holds what `bin/omawriter` did inline: decide whether `build/qml/Omarky/Native/libomarkynative.so` is stale (missing, older than a source under `native/`, or built against another Qt version), run cmake into the app's `build/` with Ninja when present, log to `<state>/build.log`, and record the Qt version. It returns the import path to put on `QML_IMPORT_PATH`, or nil when the build fails or cmake is absent.

```ruby
native = Omarky::Native.new(root: root, source: File.join(root, "vendor/omarky/native"), state_dir: app.state_dir)
path = native.ensure(required: true)    # OmaWriter: exit 1 with a notification when it fails
exit app.open(targets, foreground: foreground, env: { "QML_IMPORT_PATH" => path })
```

OmaWriter requires it, as today. OmaRead does not call it in this step; step 3 adds the call with `required: false`, and the sheet runs plain when there is no module.

## Tests and checks

| Where | What passes |
|---|---|
| Omarky `tools/test` | The existing suites, `tst_editing`, `tst_highlighter` (with the build), the Ruby suites with a `Native` test on a fake source tree |
| OmaWriter `tools/test` | The library's suites, then nothing of its own until it has QML again |
| OmaWriter `tools/check` | Unchanged expectations, against the vendored editor; `--plain` repeats them without the module |
| OmaWriter, by hand | A window opens from the launcher, a second launch hands over, the log is clean, spelling still underlines |
| OmaRead `tools/test` and `tools/check-changes` | Unchanged, on the new library commit |

## Versions

Omarky goes to 0.2.0 (the editor, `Buffer`, `PopupMenu`, `Omarky::Native`). OmaWriter's unreleased entry notes that its editor now comes from the library. OmaRead's submodule moves to the same commit so both apps vendor one version.

## Out of scope

The sheet in OmaRead, any change to how the editor looks or behaves, and OmaWriter's Settings. The decision record for the move is Omarky 0016.
