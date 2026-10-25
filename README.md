# Omarky

The shared library behind [OmaRead](https://github.com/keithrowell/omaread) and [OmaWriter](https://github.com/keithrowell/omawriter), Keith Rowell's Markdown apps for [Omarchy](https://omarchy.org). It holds everything both apps draw on, so code can flow from either app into the other: the renderer, the diff engine, the chrome, the launcher, the tests and the samples. The apps are thin: a shell, a window, a header, and a launcher of a few lines.

Version 0.1.0, split out of OmaRead 0.4.0 on 26 October 2026. QML on Quickshell, plain JavaScript, and Ruby for the launcher.

## What is here

| Path | Holds |
|---|---|
| `components/` | The reading column (`MarkdownView` and its blocks), change marks, `Changes` (comparing two versions), the version list, and the chrome both apps use: Toast, FindBar, Banner, ChipButton, Glyph, KeyCap, the offscreen `Shooter` |
| `services/` | Theme (follows the Omarchy theme), Reading (type and measure), Prefs, Doc (a watched file), Highlight (code colours from `colors.toml`) |
| `lib/` | The Markdown parser and block model, inline runs, front matter, footnotes, and `diff/` (word diffs, alignment, the comparison, the fold) |
| `Commons/`, `Ui/` | Copied from the Omarchy shell (MIT) |
| `vendor/` | markdown-it |
| `launcher/` | Ruby, standard library only: `Omarky::Instance` (one background process per app, hand-off over IPC), `History`, `Resolver` and `Versions` (a file's git versions as people and times) |
| `test/` | `tst_*.qml` for the JavaScript, minitest for the Ruby; `tools/test` runs both |
| `samples/` | Documents the apps' screenshots and checks use, and `changes/make-repo`, which builds a sample git history |
| `docs/decisions/` | Why things are the way they are |

## Using it from an app

Quickshell imports only from under the shell's root directory, so an app vendors Omarky as a git submodule and links the directories it needs into its root:

```
vendor/omarky              the submodule
ui/shell.qml               the app
ui/Commons -> ../vendor/omarky/Commons     likewise Ui, components, services, lib, vendor
ui/app/                    the app's own QML, with a qmldir listing its types
```

The import names stay Quickshell's: `qs.components`, `qs.services`, `qs.Commons`, `qs.Ui`, and `qs.app` for the app's own. Each app has a `tools/vendor` that moves the submodule to this repository's HEAD while developing: commit here, run it there, and the app sees the change.

The launcher side:

```ruby
$LOAD_PATH.unshift(File.expand_path("../vendor/omarky/launcher", __dir__))
require "omarky"
app = Omarky::Instance.new(name: "omaread", root: ROOT)   # shell: "ui/shell.qml" by default
exit app.open(targets, foreground: false)
```

`open` hands the targets to a running instance over IPC (`qs ipc call <name> open TARGET`) or starts one detached, logging to `~/.local/state/<name>/qs.log`. The window reads `<NAME>_OPEN`, one target per line.

## Tests

```
tools/test                            everything
tools/test -input test/tst_words.qml  one QML suite
tools/test --ruby                     Ruby only
```

## Licence

MIT. `Commons/` and `Ui/` are copied from the Omarchy shell (MIT) and `vendor/markdown-it.js` is markdown-it (MIT).
