# OmaRead

OmaRead opens a Markdown file and renders it for reading, in a native Quickshell window on
Omarchy. It follows your Omarchy theme live, keeps your place when the file changes on disk, and
gives each block (tables, code, alerts, front matter) its own component rather than a web view.
It is a reader only; there is no editing.

![A long spec in gruvbox with the outline open](docs/screenshots/01-spec-outline-gruvbox.png)

## Install

```
ops/install
```

This links `bin/omaread` into `~/.local/bin`, installs the desktop entry and the icon, and prints
a hint if code highlighting is missing. Code blocks are coloured by KSyntaxHighlighting from the
Arch package `syntax-highlighting`; without it they show as plain monospace. To add it:

```
sudo pacman -S --needed syntax-highlighting
```

It needs Quickshell 0.3 and Qt 6, which Omarchy already has, and the iA Writer fonts (Quattro S
and Mono S).

## Run

```
omaread path/to/file.md
omaread spec.md#5-window-and-behaviour
omaread
```

The first launch starts one background process. Every later `omaread file.md` hands the file to
it over IPC and opens a new window in about 50 ms. With no file you get a window with your recent
files. The window class is `omaread` for Hyprland rules, and the log is in
`~/.local/state/omaread/qs.log`.

## Keys

| Key | Does |
|---|---|
| `j` `k` `↓` `↑` | Scroll |
| `Space` `Shift+Space` | Page down, page up |
| `g g` `G` | Top, bottom |
| `Ctrl+\` | Show or hide the outline |
| `W` | Switch between the reading measure (68 characters) and the wide one (100) |
| `Ctrl++` `Ctrl+-` `Ctrl+0` | Zoom the text (remembered) |
| `Ctrl+F` or `/` | Find; `Enter` and `Shift+Enter` (or `n` and `N`) step through matches, `Esc` closes |
| Right-click a block | Copy its Markdown source |
| `Ctrl+Shift+C` | Copy the Markdown of the block under the mouse |
| `Ctrl+Shift+A` | Copy the whole file |
| `Ctrl+O` | Open a file (you can also drop one on the window) |
| `Ctrl+R` | Reload |
| `Ctrl+W` or `q` | Close the window |
| `?` | Show all of this |

Hovering a heading shows a `#` in the margin; clicking it copies `file.md#slug`. Links to other
Markdown files open in a new OmaRead window at their `#anchor`; web and mail links open with
`xdg-open`.

## Make it the default Markdown app

```
xdg-mime default omaread.desktop text/markdown
```

## Development

| Command | What it does |
|---|---|
| `tools/test` | Runs the JavaScript unit tests (parser, inline, code, theme) headless |
| `tools/screenshot [sample…] [--themes a,b]` | Renders samples under themes to `shots/`, offscreen, and fails on any warning in the log |
| `tools/dev start FILE` | Starts a private offscreen instance to drive over IPC (`state`, `key`, `shot`) |
| `tools/check-live` | Edits, renames, deletes and restores a file under a running instance |
| `tools/check-theme` | Switches a fake Omarchy theme under a running instance |
| `tools/gen-long` | Regenerates `samples/long.md` |

`docs/spec.md` is the brief, `docs/decisions/` records the choices made while building it, and
`docs/REPORT.md` says what was built and what is still missing.
