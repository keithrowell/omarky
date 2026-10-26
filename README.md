# Omarky

Markdown tools for [Omarchy](https://omarchy.org): a reader that makes a plain text file a pleasure to read, a writer in the spirit of Byword, and the changes between two versions of a document shown in the reading column. Built by [Keith Rowell](https://github.com/keithrowell) in QML on Quickshell, with Ruby for the command line.

The site: [keithrowell.github.io/omarky](https://keithrowell.github.io/omarky/).

![OmarkyReader in tokyo-night](docs/screenshots/reader/hero.png)

## Principles

- **The file is the document.** Both apps open the Markdown file as it is on disk and never keep a copy of their own. The writer saves the text exactly as you typed it; the reader reloads in place when another program changes the file. There is no database, no export step and no format of ours.
- **Reading deserves its own app.** A preview pane in an editor is a second-class view. OmarkyReader has one job, and everything in it (the measure, the type, the outline, the keys) is chosen for reading a document from start to finish.
- **The desktop decides how it looks.** Colours come from the current Omarchy theme and follow it as you switch, light or dark. There is no theme picker in either app.
- **Nothing to configure.** One background process per app, one window per file, keys you can read in a sheet with `?`. Preferences are the few things that change as you read: the zoom and the recent files.
- **Versions are people and times.** When a document lives in git, its history is "Danny, Friday 23 October" and "me, yesterday", never a commit hash. The reader shows what changed between two of them in the same column you read in.
- **Editing from the reader stays small.** A block or a section at a time, in the writer's editor, over the page. For a document, use the writer.

## OmarkyReader

```
omarky read notes/plan.md
omarky read docs/spec.md#window-and-behaviour
```

![Reading prose in gruvbox](docs/screenshots/reader/reading.png)

A reading column at a measure of about 68 characters, in the prose font Omarchy's theme suggests, with headings, lists, quotes, tables, code, images, footnotes, task lists and alerts set the way a typesetter would. The outline on the left follows you through the document and jumps on a click. Links to other Markdown files open in a new window at their heading; web links open in your browser. Code blocks take their colours from the theme's own `colors.toml`.

![Code in rose-pine](docs/screenshots/reader/code.png)

![The same page in six Omarchy themes](docs/screenshots/reader/themes.png)

Find (`Ctrl+F` or `/`) steps through matches across the whole document. `W` widens the measure for tables and code. Right-click any block to copy its Markdown source; a hover on a heading shows a `#` that copies `file.md#heading`. The file is watched, so an edit in another program shows up in place, with the page kept on the same paragraph.

### Changes

```
omarky read proposal.md --from danny
omarky read proposal.md --from yesterday --to "danny fri"
omarky changes proposal.md
```

![Changes: the file now against Danny's version](docs/screenshots/reader/changes.png)

When the file has check-ins in git, a branching chip joins the header. Click it (or press `V`) and pick a version, and the window compares the file as it is now with that version in the same column: added words on a wash in the theme's green, removed words faded under a strike in its red, and a tag in the margin for each paragraph that changed. The pill in the header names the two ends and counts the changes; the outline counts them per section.

![The fold: only what changed](docs/screenshots/reader/changes-fold.png)

`F` folds everything that did not change, so a long document with three edits is three paragraphs and a few hairlines. `N` and `P` step between changes. When the newer side is the file on disk, an edit in your editor re-runs the comparison and keeps your place.

![The version list](docs/screenshots/reader/changes-versions.png)

A version is a person and a time: `danny`, `me`, `yesterday`, `a week ago`, `fri`, `23 oct`, `danny fri`, `sent` (the date in a `SENT.md` beside the file), `before danny`, or anything git understands. `--list` prints the file's versions with who, when and the message, and opens nothing.

### Editing a block

![The edit sheet over a reworded paragraph](docs/screenshots/reader/edit.png)

Reading and finding a sentence to fix, press `E`. The block under the mouse opens in a sheet over the page, in OmarkyWriter's editor, with the blocks before and after it faint around it. `Shift+E` opens the whole section. Type, then `Ctrl+Enter`: the file is written and the page reloads under the sheet. `Esc` closes without writing. The sheet never writes over a change that landed while it was open. In changes mode a reworded block shows its older wording with a "Use this" chip, so putting a sentence back is two keys.

## OmarkyWriter

```
omarky write notes/essay.md
omarky write
omarky write --end journal.md
```

![OmarkyWriter in tokyo-night](docs/screenshots/writer/editor.png)

You type plain Markdown and it looks finished as you write: emphasis leans, code sits in a chip, links read as links, and the marks that make it happen fade back. Heading marks, list markers and quote marks hang in the left margin, so the text keeps one clean edge. The text in the window is always exactly the file's Markdown; the keys below are the only things that change it.

| Keys | Does |
|---|---|
| `Enter` | Continues a list, a numbered list (counting up), a task list or a quote; on an empty item, ends the list |
| `Tab`, `Shift+Tab` | Indents or outdents a list item |
| `Ctrl+B`, `Ctrl+I`, `Ctrl+E` | Bold, italic, inline code; again to remove |
| `Ctrl+K` | A link around the selection, cursor in the URL |
| `Ctrl+1` to `Ctrl+6`, `Ctrl+0` | Heading level, or back to a paragraph |

![Focus mode in rose-pine](docs/screenshots/writer/focus.png)

Focus (`Ctrl+Shift+F`) fades everything but the paragraph you are in. Typewriter scrolling (`Ctrl+Shift+T`) keeps the line you are writing in the middle of the window. The header and the word count step aside while you type and come back when you move the mouse. Misspelt words get a quiet line once you have moved past them, never while you are typing them; right-click one for suggestions. Spelling is Australian English through Sonnet and Hunspell.

![Preview in tokyo-night](docs/screenshots/writer/preview.png)

`Ctrl+P` shows the document rendered by the reader, opened at the block you were writing in, and `Esc` brings you back to the same place in the source. With no file you get a new untitled document, saved as a draft while you type; `Ctrl+R` lists recent files and drafts, and `Ctrl+Shift+S` gives a draft a name. Named files save themselves a moment after you stop typing. A file changed by another program is reloaded in place when you have nothing unsaved, and offered as a choice when you do.

![Light theme, catppuccin-latte](docs/screenshots/writer/light.png)

## Install

On Omarchy, with `quickshell`, `ruby`, `ttf-ia-writer`, `sonnet` and `hunspell-en_au` installed (and `cmake` with the Qt 6 headers for the editor's native module, which is optional):

```
git clone https://github.com/keithrowell/omarky.git ~/.local/src/omarky
~/.local/src/omarky/ops/install
```

The script links `omarky` into `~/.local/bin`, adds a desktop entry and an icon for each app, and builds the native module when it can. It leaves the default Markdown app alone. To make the reader the default:

```
xdg-mime default omarky-reader.desktop text/markdown
```

To update, pull and run the install script again. The reader's state (zoom, recent files) lives in `~/.local/state/omarky-reader`, the writer's (settings, recent files, drafts) in `~/.local/state/omarky-writer`, and each app logs to `qs.log` there.

## Keys in the reader

| Key | Does |
|---|---|
| `j` `k` `↓` `↑` | Scroll |
| `Space` `Shift+Space` | Page down, page up |
| `g g` `G` | Top, bottom |
| `O` or `Ctrl+\` | Show or hide the outline |
| `V` | Choose the versions to compare (when the file has check-ins) |
| `N` `P` | Next and previous change |
| `F` | Only what changed, or everything |
| `E` `Shift+E` | Edit the block under the mouse, or its section, in a sheet; `Ctrl+Enter` saves, `Esc` cancels |
| `W` | Switch between the reading measure (68 characters) and a wide one (100) |
| `Ctrl++` `Ctrl+-` `Ctrl+0` | Zoom the text (remembered) |
| `Ctrl+F` or `/` | Find; `Enter` and `Shift+Enter` (or `n` and `N`) step through matches, `Esc` closes |
| Right-click a block | Copy its Markdown source |
| `Ctrl+Shift+C` | Copy the Markdown of the block under the mouse |
| `Ctrl+Shift+A` | Copy the whole file |
| `Ctrl+O` | Open a file (or drop one on the window) |
| `Ctrl+R` | Reload |
| `Ctrl+W` or `q` | Close the window |
| `Esc` | Close the list or the find bar, or go back from a comparison to reading |
| `?` | Show all of this |

The writer's `Ctrl+/` shows its own sheet: the editing keys above plus `Ctrl+Shift+M` to cycle the font through iA Writer Quattro S, Duospace and Mono S, `Ctrl+=` and `Ctrl+-` for size, `Ctrl+Shift+L` for spelling, `Ctrl+F` for find, `Ctrl+N` for a new window, `Ctrl+O` to open, `Ctrl+W` to close.

## Architecture

Both apps are QML on [Quickshell](https://quickshell.org), the toolkit Omarchy's own shell is built with, so they are native Wayland windows with no web view and no Electron. They share one library, the root of this repository, and each app is a thin shell on it:

| Path | Holds |
|---|---|
| `components/`, `services/`, `lib/` | The library: the Markdown parser and block model, the reading column and its blocks, the diff engine (`lib/diff/`), the editor, the chrome both apps use, and the services (theme, type, preferences, a watched file, code colours) |
| `native/` | The one native piece: a `QSyntaxHighlighter` that paints the writer's editor and sets its line layout, as the `Omarky.Native` QML module. Built by the launcher on first run; the editor runs plain without it |
| `launcher/` | Ruby, standard library only: one background process per app with hand-off over IPC, the native build, and a file's git history as people and times |
| `reader/`, `writer/` | The apps: a shell, a window, their own QML in `ui/app/`, a command line, and the offscreen checks that drive them |
| `bin/omarky` | The command: `read`, `changes`, `write`, `build` |
| `docs/decisions/` | Why things are the way they are, one numbered record per decision |

The parser is markdown-it with the blocks rendered as a flat list, one delegate per block (decision 0001), which is what keeps a 5,000-line document scrolling smoothly. The reader's window never runs git: the launcher resolves "danny fri" to a version and hands the window two texts and two labels (decision 0013). The diff engine aligns the two documents by section and paragraph, then by word, and marks the newer document's runs (decision 0012). The highlighter sets line layout outside the undo history so `Ctrl+Z` only ever moves text (decision 0015). The editor lives in the library so the reader can borrow it for one block (decisions 0016 and 0018).

## Development

```
tools/test                              every suite: the library's QML and Ruby, the reader's CLI
reader/tools/check-changes              changes mode, offscreen, over IPC
reader/tools/check-sheet [--plain]      the edit sheet, with and without the native module
writer/tools/check [--plain]            the writer: keys, autosave, reload from disk
reader/tools/readme-shots               the reader's screenshots, under Omarchy themes
writer/tools/shot FILE OUT.png --theme X   one writer screenshot
```

Every screenshot in this README is of a sample document under `samples/`, rendered offscreen. `docs/superpowers/specs/` holds the design notes each piece was built from.

## Licence

MIT. `Commons/` and `Ui/` are copied from the Omarchy shell (MIT) and `vendor/markdown-it.js` is markdown-it (MIT).
