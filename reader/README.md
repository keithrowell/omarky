# OmaRead

A Markdown reader for [Omarchy](https://omarchy.org). It opens a file and sets it the way a
good book is set: a 68-character measure, real leading, and every block (tables, code, alerts,
front matter) drawn as its own native component. It follows your Omarchy theme as you switch,
keeps your place while an editor or agent rewrites the file, and is a reader only.

![OmaRead in tokyo-night and catppuccin-latte](docs/screenshots/hero.png)

Version 0.2.0. Built in QML on Quickshell and Omarchy's own shell components, with no web view.

## Install

On Omarchy (Arch Linux with Hyprland):

```
sudo pacman -S --needed quickshell ttf-ia-writer syntax-highlighting
git clone https://github.com/keithrowell/omaread.git ~/.local/src/omaread
~/.local/src/omaread/ops/install
```

The install script links `omaread` into `~/.local/bin` and adds a desktop entry and icon. It
does not make OmaRead your default Markdown app; to do that:

```
xdg-mime default omaread.desktop text/markdown
```

To update:

```
git -C ~/.local/src/omaread pull
```

`syntax-highlighting` (KDE's KSyntaxHighlighting) colours code blocks. Without it, code shows as
plain monospace. The fonts are iA Writer Quattro S and Mono S from `ttf-ia-writer`, and the icons
come from JetBrainsMono Nerd Font, which Omarchy installs.

## Use

```
omaread notes/plan.md
omaread docs/spec.md#5-window-and-behaviour
omaread
```

One background process owns every window. A second `omaread file.md` hands the file to it and
opens a new window straight away. With no file you get your recent files. Hyprland sees the
window class `omaread`.

## What it does

![Long-form prose in gruvbox, with the outline](docs/screenshots/reading.png)

The reading column is measured from the font, not the window, and the outline marks the section
you are in as you scroll. The thin line along the top edge is how far through the file you are.

![Code in rose-pine](docs/screenshots/code.png)

Code is highlighted in your theme's own colours: OmaRead generates a highlighting theme from each
Omarchy `colors.toml`. Blocks get a language badge, a copy button on hover, and line numbers past
eight lines. Diffs get green and red bands and a `+N −M` count.

![Tables in flexoki-light](docs/screenshots/tables.png)

Tables are a real grid: alignment from the separator row, tabular figures, and columns that fit
the page or scroll inside their own frame when they cannot.

![Lists and tasks in tokyo-night](docs/screenshots/structure.png)

Bullets and numbers hang in the margin, tasks get drawn checkboxes, and headings sit on a 1.25
scale.

![GitHub alerts in rose-pine](docs/screenshots/alerts.png)

`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` and `[!CAUTION]` become tinted cards. Front
matter becomes a card too, with statuses and dates as pills, whether it is YAML between `---`
fences or bare `key: value` lines ended by a blank line. HTML comments, such as agent
snapshot headers, are hidden. HTML that is only `<img>` tags, the usual way to put screenshots side
by side, shows the images in a row; any other raw HTML is shown as source, never interpreted.

![Find, in gruvbox](docs/screenshots/find.png)

Ctrl+F finds across the whole document. When the file changes on disk it reloads in place and
keeps you on the same paragraph, even when text is added above it.

![The same page in six Omarchy themes](docs/screenshots/themes.png)

## Keys

| Key | Does |
|---|---|
| `j` `k` `↓` `↑` | Scroll |
| `Space` `Shift+Space` | Page down, page up |
| `g g` `G` | Top, bottom |
| `Ctrl+\` | Show or hide the outline |
| `W` | Switch between the reading measure (68 characters) and a wide one (100) |
| `Ctrl++` `Ctrl+-` `Ctrl+0` | Zoom the text (remembered) |
| `Ctrl+F` or `/` | Find; `Enter` and `Shift+Enter` (or `n` and `N`) step through matches, `Esc` closes |
| Right-click a block | Copy its Markdown source |
| `Ctrl+Shift+C` | Copy the Markdown of the block under the mouse |
| `Ctrl+Shift+A` | Copy the whole file |
| `Ctrl+O` | Open a file (or drop one on the window) |
| `Ctrl+R` | Reload |
| `Ctrl+W` or `q` | Close the window |
| `?` | Show all of this |

Hovering a heading shows a `#` in the margin; clicking it copies `file.md#heading`. Links to
other Markdown files open in a new window at their anchor, and web links open in your browser.

## Development

| Command | What it does |
|---|---|
| `tools/test` | Runs the JavaScript unit tests (parser, inline, code, theme) headless |
| `tools/screenshot [sample…] [--themes a,b]` | Renders samples under themes to `shots/`, offscreen, and fails on any warning in the log |
| `tools/readme-shots` | Renders the screenshots in this README |
| `tools/dev start FILE` | Starts a private offscreen instance to drive over IPC (`state`, `key`, `shot`) |
| `tools/check-live` | Edits, renames, deletes and restores a file under a running instance |
| `tools/check-theme` | Switches a fake Omarchy theme under a running instance |

`docs/spec.md` is the original brief, `docs/decisions/` records the choices made while building
it, and `docs/REPORT.md` covers how it was checked and what is still missing. The log is in
`~/.local/state/omaread/qs.log`.

## Using the renderer in another app

The reading column is a component of its own, `components/MarkdownView.qml`. Link OmaRead's
`Commons`, `Ui`, `components`, `services`, `lib` and `vendor` directories into your Quickshell
config and it takes a Markdown string (or a file path) and hands links back:

```qml
import qs.components

MarkdownView {
  markdown: article.text
  baseUrl: article.url          // relative images and links resolve against it
  externalLinks: true           // web links come to you instead of the browser
  onLinkActivated: url => openArticle(url)
}
```

It also has `path` (a file, watched and reloaded), `wide`, `documentName`, the `notice(text)`
and `openFile(path, anchor)` signals, and `doc`, `view`, `finder` and `progress` for building
an outline, find or a progress line around it, as `components/ReaderWindow.qml` does.
MarkdownView draws no background of its own: paint `Theme.bg` behind it (from `qs.services`), as
the reader window does. A new `markdown` string opens at the top with find cleared; an empty
one clears the view.

A string read from a local file can still find its images and sibling files: give `baseUrl` a
directory (`/abs/dir` or `file:///abs/dir`), and relative links to `.md` files come back through
`openFile`. Set `keepPlace: true` when a new string is the same document edited (a file changed
on disk), and the reader stays where they were instead of going back to the top; set `markdown`
to `""` before showing a different document.

### Fonts

The reading column uses three families, each of which an app or the environment can change:

| Role | Default | Environment | From QML |
|---|---|---|---|
| Prose (paragraphs, lists, tables) | iA Writer Quattro S | `OMAREAD_PROSE_FONT` | `Reading.proseFamily` |
| Headings, `Family/Style` | iA Writer Quattro S/Bold | `OMAREAD_HEADING_FONT` | `Reading.headingFamily` |
| Code and labels | iA Writer Mono S | `OMAREAD_MONO_FONT` (or the older `OMAREAD_CODE_FONT`) | `Reading.monoFamily` |

```qml
import qs.services

Component.onCompleted: {
  Reading.proseFamily = "IBM Plex Sans"
  Reading.headingFamily = "IBM Plex Sans/Bold"
  Reading.monoFamily = "IBM Plex Mono"
}
```

The environment wins over the app, so it stays a switch for comparing candidates. A family that
is not installed falls back to the default above (a heading's style falls back with it), never
to whatever Qt would substitute, so an app can ask for a font before it is installed. The
68-character measure is computed from whichever prose font is in use. `Reading.refreshFonts()`
re-reads the installed families after a font is installed while the app is running.

## Licence

MIT. `Commons/` and `Ui/` are copied from the Omarchy shell (MIT) and `vendor/markdown-it.js` is
markdown-it (MIT).
