# OmaRead: build report

OmaRead is built to `docs/spec.md` and installed locally. `omaread file.md` works from anywhere,
all 48 unit tests pass, and the qs log is clean for every sample in all six review themes (528
screenshots, wide and narrow). Omawrite is still the default Markdown app; see "What changed on
this machine" below.

## What was built

A Quickshell 0.3.1 app in QML and plain JavaScript, with no C++ and no web engine.

- `lib/blocks.js` turns markdown-it's token stream into a flat list of blocks with source line
  maps: front matter, headings with GitHub slugs, paragraphs, lists (tight, loose, ordered,
  nested, tasks), quotes, GFM alerts, code, diffs, tables, rules, images, raw HTML and footnotes.
  `lib/inline.js` turns inline tokens into styled runs and themed Qt rich text. Both were written
  test-first (`tools/test`).
- `components/blocks/` has one component per block type, chosen by a `Loader`. The document is a
  `ListView` with a centred column measured from the body font (68 characters, or 100 wide).
- `services/Theme.qml` follows Omarchy theme switches live. `services/Highlight.qml` generates a
  KSyntaxHighlighting theme from each Omarchy `colors.toml`, so code uses the page's palette.
- `shell.qml` runs one process with a window per file. A second `omaread` call hands its file
  over IPC in about 50 ms.
- The window has the header, reading-progress hairline, outline with scroll-spy, find, live
  reload, copy, zoom, recent files, drag and drop, the empty state and every key in spec §5.
- `bin/omaread`, `ops/install`, `ops/omaread.desktop` and the icon `ops/omaread.svg`.
- `tools/screenshot` renders samples under any theme offscreen and fails on any log warning.
  `tools/dev`, `tools/check-live` and `tools/check-theme` drive a private instance for the
  behaviour checks.

## Screenshots

| | |
|---|---|
| ![](screenshots/01-spec-outline-gruvbox.png) | ![](screenshots/02-lists-quotes-alerts-tokyo-night.png) |
| The spec in gruvbox, outline open | Lists, tasks, quotes and alerts in tokyo-night |
| ![](screenshots/03-code-diff-catppuccin-latte.png) | ![](screenshots/04-tables-flexoki-light.png) |
| Code and diffs in catppuccin-latte | Tables in flexoki-light: numeric, and a wide one that scrolls |
| ![](screenshots/05-front-matter-adr-rose-pine.png) | ![](screenshots/06-alerts-matte-black.png) |
| ADR-0003 with its front matter card, rose-pine | Alerts in matte-black |
| ![](screenshots/07-find-reloaded-tokyo-night.png) | ![](screenshots/08-empty-state-recent-gruvbox.png) |
| Find with the current match, the reloaded pulse and the deleted-file banner | The empty state with recent files |

## Decisions

Each is a few lines in `docs/decisions/`.

| # | Decision |
|---|---|
| 0001 | A flat block list in a ListView; nested structure lives inside each block |
| 0002 | Parse with `html: true` so comments can be hidden; raw HTML is always shown as text |
| 0003 | Pin iA Writer Quattro S to its Regular style (its Bold file declares a regular weight) |
| 0004 | Own linkify matcher (linkify-it never matches under V4) and own footnote plugin |
| 0005 | Headings in Quattro S Bold, chosen over Duo S and Mono S from screenshots |
| 0006 | KSH themes generated from `colors.toml` into a private data dir |
| 0007 | Code in iA Writer Mono S, chosen over JetBrains Mono (heavier, with ligatures) |
| 0008 | Two log categories filtered: a minified-vendor lint and a Quickshell portal warning |
| 0009 | Scrolling: warm each language's highlighter after open (worst step 82 ms to 19 ms) |
| 0010 | Find by piece ids, reload anchoring, reduced motion, file dialog, copy keys, state |

Two smaller choices are worth knowing. Inline code chips are rounded rectangles drawn under the
text from its own layout, since Qt rich text cannot round a background. Image corners are masked
with vector shapes, because Quickshell's `ClippingRectangle` draws nothing offscreen.

## How it was checked

- **Look:** every block type was screenshotted and reviewed after it was built, then every sample
  in gruvbox, tokyo-night, catppuccin-latte, rose-pine, flexoki-light and matte-black. The polish
  pass fixed table column widths, outline type size and spacing around rules.
- **Behaviour:** checked on an offscreen instance over IPC. Second launch with `#anchor`, `j`/`k`,
  Space, `g g`/`G`, outline and width toggles, zoom (persisted), find and its stepping, `#anchor`
  and relative `.md` links, Ctrl+Shift+C, Copy all and `q` all behaved as specified.
- **Live reload:** `tools/check-live` covered an append, three paragraphs inserted above the
  reading position (the view stayed on the same block), an atomic rename, a burst of ten writes
  (one reload), delete (banner, content kept) and restore.
- **Live theme:** `tools/check-theme` switched a fake Omarchy `current/` tree through four themes
  the way `omarchy theme set` does. Colours, code colours and scroll position all followed.
- **Real Wayland window**, briefly: Hyprland class `omaread`, title `OmaRead — code.md`, Copy all
  reached the Wayland clipboard, and Ctrl+O opened the GTK file chooser.
- **Performance:** `long.md` (5,422 lines) parses in about 50 ms and is on screen in about 650 ms
  from launch. Scrolling it end to end costs under 1 ms per step on average, worst 19 ms.
- **Malformed input:** unclosed markup, ragged tables, 24-deep lists, 15-deep quotes, a 3,000
  character line, binary junk and an empty file all render without errors.
- **Missing highlighting:** with `OMAREAD_NO_KSH=1` code falls back to plain monospace.

## Known gaps

- Mouse-only behaviours were not driven with a real pointer, because Keith was using the desktop
  and a Factory permission prompt was open. That covers the hover `#` on headings, right-click
  copy, drag and drop, and wheel scrolling (including sideways scrolling in code and tables). Their
  code paths were exercised over IPC where possible (block copy, links); the hover and wheel
  handlers were not.
- Killing OmaRead while the GTK file dialog is open leaves the process stuck until SIGKILL. Closing
  the dialog first, the normal path, is fine.
- A theme added after OmaRead starts has no generated code theme until the next start. Its code
  uses KSH's default light or dark theme instead.
- Find does not search front matter, raw HTML or image captions.
- Text selection works within one block, as the spec asks; it does not run across blocks.
- Matte-black's palette maps `yellow` to a red and `green` to amber, so its warning alerts and
  draft pills read red. OmaRead uses the theme's colours as given.
- Offscreen screenshots are at 1x, and the real window at Keith's 1.6 scale was checked only once.
- Inline images inside a paragraph show as a link with their alt text; only an image on its own
  line is drawn.

## What changed on this machine

- `~/.local/bin/omaread` links to `bin/omaread`. The desktop entry and icon were installed under
  `~/.local/share`.
- Installing a second `text/markdown` handler made OmaRead the implicit default, because nothing
  pinned one. The spec leaves that choice to Keith, so the install pinned the previous default
  back: `~/.config/mimeapps.list` now has `text/markdown=omawrite.desktop`. To switch:

  ```
  xdg-mime default omaread.desktop text/markdown
  ```

- Generated code themes live in `~/.local/share/omaread/ksh`, and zoom and recent files in
  `~/.local/state/omaread`.
- The real Omarchy theme was never switched.
