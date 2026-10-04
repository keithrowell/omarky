# OmaRead: a beautiful Markdown reader for Omarchy

Status: approved design, 30 Sep 2026. Build from this document alone. The conversation that
produced it is gone; everything you need is here or in the files it points to.

## 1. What and why

OmaRead is a desktop app that **opens a Markdown file and renders it beautifully**. It is a
reader only. The owner (Keith) reads a lot of Markdown every day: specs, ADRs and plans, much of it
written by agents. He wants reading it to feel as good as Byword or iA Writer's preview, only more
polished, and native to his Omarchy (Hyprland) desktop.

The one thing that matters most is **how good the rendered document looks.** Every decision should
favour the quality of the rendering and the typography.

It should look like a sibling of the **Agentile Factory** app (`~/lab/factory/ui`), which Keith
loves. It is built the same way, a native Quickshell QML app on Omarchy's own shell components.
Take its visual language (spacing, hairlines, tinted surfaces, live theme colours, the diff look)
and push it further for long-form reading. Don't copy its screens.

Omarchy already ships an editor, **Omawrite**. OmaRead is not an editor, and it does not compete
with it.

### Non-goals (v1)

- **Editing** of any kind. Keith will decide on editing later. Don't design for it, but don't paint
  it into a corner either: keep the parser and renderer separate from the window.
- **Folders or libraries.** It opens single files only.
- **WebEngine, Electron or a browser engine.** They were rejected: 272 MB, they break under
  Quickshell, and they're off-style for Omarchy. Everything is native QML.
- **Maths (KaTeX) and Mermaid diagrams.** Render these blocks as normal code blocks with a
  language badge.
- **Packaging for the AUR or the Omarchy marketplace.** Make it installable locally (§9). Keep it
  clean enough that this could come later.

## 2. Stack and constraints

- **Quickshell 0.3.1** (`qs -p <dir>/shell.qml`) on **Qt 6.11**, Arch Linux (arm64), Hyprland,
  Omarchy.
- **QML plus plain JS** (Qt's V4 engine) only. No C++ unless something is impossible without it.
  If so, stop and write down why in `docs/decisions/`.
- **Omarchy shell base.** Copy `Commons/` (`Color`, `Style`, `Util`, `Border*`) and whatever `Ui/`
  components you use from `~/.local/share/omarchy/shell/`. The Factory did exactly this; compare
  with `~/lab/factory/ui/Commons` and `~/lab/factory/ui/Ui`, and note that the Factory's `Util.qml`
  differs slightly from Omarchy's. `qs` resolves `import qs.Commons` relative to the shell root.
  Put a `README` note in `Commons/` saying where each file was copied from and at which date.
- **Parser.** Use `vendor/markdown-it.js`, which is already in the repo. It is markdown-it 14.3.2,
  MIT, wrapped for V4 with a CommonJS shim: `.pragma library` + `var module={exports:{}}`, with
  `get()` returning the module. Use it as `import "../vendor/markdown-it.js" as MDI; var md =
  MDI.get()({ html: false, linkify: true, typographer: true })`. **Use `md.parse(src, env)` to get
  the token stream, not `.render()`.** You build QML components from the tokens.
  - V4 gotchas that are known to matter:
    - no ES modules;
    - no optional catch binding;
    - no regex `s` flag;
    - you can't assign to the global object.

    `marked`, `commonmark.js` and `highlight.js` all fail in V4, so don't use them.
  - Any markdown-it plugin you vendor must get the same shim and pass a load test. Candidates are
    task lists, footnotes and front matter. Writing small token post-processors yourself is fine and
    often simpler: GFM alerts, task-list items and front matter are each about 20 lines.
- **Code highlighting.** Use the KSyntaxHighlighting QML module: `import org.kde.syntaxhighlighting`,
  then `SyntaxHighlighter { textEdit: …; definition: …; theme: … }`. It comes from the Arch package
  `syntax-highlighting`, which may not be installed yet; Keith installs it with
  `sudo pacman -S --needed syntax-highlighting`. Load it through a `Loader` or a guarded component,
  so that a **missing module degrades to plain monospace code**, never an error or a blank block.
  Map its theme to Omarchy colours. Either pick the KSH built-in theme nearest in mode, or better,
  generate a KSH theme JSON from `colors.toml` at runtime (research KSH's theme format). Do what
  looks best, and record the choice.
- **Fonts.** These are installed and verified with `fc-list`:
  - Prose: **iA Writer Quattro S**.
  - Alternative prose font to try: iA Writer Duo S.
  - Code: **iA Writer Mono S**, or **JetBrainsMono Nerd Font** (family "JetBrainsMono Nerd Font").
    Compare the two in screenshots and pick one.
  - Headings and structural labels: the Factory's direction is mono for structure and sans or
    quasi-proportional for prose. Try headings in iA Writer Duo S or Mono S against Quattro S bold,
    and choose from screenshots.
  - Never rely on the `sans-serif`/`serif` aliases; on this machine they are Liberation.
- **Theme.**
  - The active theme is copied to `~/.local/state/omarchy/current/theme/`, which contains
    `colors.toml` and `shell.toml`. Its name is in `~/.local/state/omarchy/current/theme.name`.
  - `colors.toml` holds:
    - `mode`, `accent`, `selection`, `muted`;
    - `background`, `dark_background`, `darker_background`, `lighter_background`;
    - `foreground`, `dark_foreground`, `light_foreground`, `bright_foreground`;
    - `red`, `yellow`, `orange`, `green`, `cyan`, `blue`, `magenta`, `brown`, and `bright_*`
      variants of each. Keys can be missing, so fall back as `~/lab/factory/ui/services/Theme.qml`
      does.
  - A theme switch runs `rm -rf current/theme; mv next-theme current/theme` and then rewrites
    `theme.name`. Follow the Factory's `Theme.qml` pattern: watch `theme.name`, reload
    `colors.toml`/`shell.toml`, feed `Color`, and call `Style.scheduleRefresh()`. Colours must
    change live, with no reload and without losing the scroll position.
  - Other themes live under `~/.local/share/omarchy/themes/<name>/colors.toml`. Use them for
    screenshots (§8). **Never switch Keith's real theme.** Provide an `OMAREAD_THEME_DIR` env
    override instead.

## 3. Repository layout (suggested; improve it if you find a better one)

```
shell.qml            ShellRoot: single instance, IPC, one window per open file
bin/omaread          launcher: resolves the file path, hands it to a running instance or starts qs
Commons/ Ui/         copied from the Omarchy shell (see §2)
services/Theme.qml   palette + live theme following (+ OMAREAD_THEME_DIR override)
services/Doc.qml     loads a file, watches it, parses it, exposes the block model
lib/blocks.js        markdown-it tokens → a flat array of block objects (pure JS, unit-tested)
lib/inline.js        inline tokens → Qt rich-text (StyledText/HTML subset) with theme colours
components/          one QML component per block type + chrome (Header, Outline, Find bar, …)
vendor/              markdown-it.js (+ any plugins), with LICENSE files
samples/             the sample documents (§8)
test/                JS unit tests for lib/*.js (runnable headless with `qml` or `qs`)
tools/screenshot     renders samples × themes to PNGs (§8)
docs/                this spec, decisions/, research/
ops/omaread.desktop  desktop entry (MimeType=text/markdown;)
```

`docs/research/render-experiment.qml` and `render-experiment.png` show the research render test:
Qt's `MarkdownText` on the left, markdown-it with CSS in a `TextEdit` on the right. Neither is the
target. The target is per-block components, which look far better than both.

## 4. Rendering model

- `lib/blocks.js` turns the token stream into a **flat list of blocks**, each with `type`, its data
  and a `srcStart`/`srcEnd` line map (from `token.map`). Nested structures (lists, quotes, callouts,
  tables) are represented inside their block object, not as separate list rows. This keeps the
  `ListView` simple and scrolling smooth.
- The document view is a `ListView` (or a `Flickable` + `Column` if you can show that performs
  better) with a **delegate chooser by block type**. It must scroll smoothly through a 5,000-line
  document; use `samples/long.md`.
- Paragraph-level text is a `Text`/`TextEdit` with rich-text inline formatting from `lib/inline.js`:
  bold, italic, strikethrough, inline code as a chip (tinted background, mono, slightly smaller),
  links in the accent colour, and soft breaks. Text inside a block is selectable
  (`TextEdit { readOnly: true; selectByMouse: true }`).
- The reading column is centred, with a **max measure of about 68 characters of body text**
  (compute it from font metrics, not a fixed pixel width). A toggle switches to a wide measure
  (about 100 characters). Margins breathe; the window never feels cramped.

### Block types and how each should look

These are starting points. Refine them against screenshots until they look excellent.

| Block | Treatment |
|---|---|
| **Front matter** (`---` YAML at the top, or bare `key: value` lines ended by a blank line) | A card, not raw YAML: title prominent if present, then key → value rows. Short values as pills (status, dates, tags as chips). Long values wrap. An empty value is a faint dash. A subtle "front matter" label. |
| **HTML comments** | Hidden entirely, including Agentile's `<!-- SNAPSHOT … -->` headers. HTML that is only `<img>` tags becomes a row of images (docs/decisions/0002). Other raw HTML shows as muted monospace. Never interpret it. |
| **Headings h1–h6** | A clear modular scale, e.g. 1.25–1.333 ratio from the body size. h1 has generous space above (except at the top) and tight space below, so it binds to its content. h1/h2 may carry a faint hairline underneath. On hover a faint `#` in the left margin; clicking it copies `file.md#slug`. Slugs follow GitHub's rules. |
| **Paragraph** | Body size from `Style.font` (rem root from `shell.toml`) scaled up for reading, roughly 1.15–1.25× the UI base, tuned by eye. Line height about 1.6. Paragraph spacing about 0.9em. |
| **Lists** | Bullets and numbers hang in the margin so the text aligns with the paragraph. Nested levels are indented with a lighter bullet. Tight and loose lists are spaced differently (markdown-it tells you which). |
| **Task list items** | `- [ ]` / `- [x]` render as drawn checkboxes (not glyphs), with the checked text slightly dimmed. Read-only. |
| **Blockquote** | An accent bar (2–3 px, rounded) on the left, text slightly dimmed and one step smaller, nested quotes stepped in. |
| **GFM alerts** (`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`) | A tinted card in the matching theme colour (blue, green, magenta, yellow, red), with an icon and the title in small caps or mono, and the body inside. |
| **Code block** | A raised or sunken panel (Factory `CodeBlock` look, more refined): rounded, hairline border, language badge top-right (mono, small, dim), a copy button appearing on hover with "Copied" feedback. Syntax-highlighted via KSH. Line numbers in a dim gutter for blocks over about 8 lines. Long lines scroll horizontally inside the panel; they never wrap. |
| **`diff` / `patch` code blocks** | The Factory `DiffView` look: added lines tinted green, removed lines tinted red (about 14% alpha), `@@` hunk headers in blue, a +/- gutter, and a header showing `+N −M`. |
| **Table** | Real grid: header row in mono small caps or bold on a tinted band, hairline row rules, generous cell padding, column alignment from the separator row (`:--`, `--:`), numbers in tabular figures, subtle zebra striping. Wider than the column: scrolls horizontally inside its own frame, with a fade at the edge. |
| **Horizontal rule** | A short, centred, thin ornament (three dots or a short hairline), not a full-width line. |
| **Image** | Local paths are resolved relative to the file. Fits the column width, keeps its aspect ratio, has rounded corners, and uses the alt text as a dim caption below. Missing image: a small neat placeholder with the alt text. Remote images load. |
| **Footnotes** | Superscript references in the accent colour. Notes are collected at the end under a hairline. Clicking scrolls to the note, and the note links back. |
| **Links** | Accent colour, with no underline until hover. See §5 for behaviour. |

Inline code, bold, italic and strikethrough must look crafted, not default. Adjust colours using
the theme's tiers: `text`, `dim`, `faint`, `raised`, `sunken`, `hairline` as in the Factory's
`Theme.qml`.

## 5. Window and behaviour

- **Opening files.**
  - `bin/omaread path/to/file.md` opens it. With no argument, it shows a calm empty state:
    "Open a Markdown file", Ctrl+O, and a recent-files list.
  - You can also drag and drop a `.md` file onto the window.
  - Ctrl+O opens a file dialog. Use a Quickshell/Qt file dialog, or shell out to a portal picker if
    needed.
- **Single instance.** Copy the Factory `shell.qml` pattern: a flock plus an `IpcHandler`. A second
  `omaread file.md` asks the running instance to open that file in a **new window**, then exits.
  One `FloatingWindow` per file; Hyprland tiles it. The window title is `OmaRead — file.md`. Set a
  stable class/app id so Hyprland rules can target it.
- **Header.**
  - A slim bar: file name, a dim parent path, and a small "reloaded" pulse after a live reload.
  - Toggles for the outline and for reading width.
  - A **reading-progress hairline** in the accent colour along the top edge.
- **Outline sidebar.** A toggle (Ctrl+\\) shows the heading tree. The current section is highlighted
  as you scroll (scroll-spy). Clicking a heading scrolls there smoothly. The sidebar is hidden by
  default on narrow windows.
- **Live reload.** Watch the file. When it changes on disk, re-parse and re-render, keeping the
  reading position anchored to the same block, or the nearest one by source line. No flicker.
  Debounce about 150 ms, because editors write in bursts. If the file is deleted, show a gentle
  banner and keep showing the last content.
- **Find.**
  - Ctrl+F opens a find bar. Matches are highlighted in every block, and the current one is
    emphasised.
  - Enter / Shift+Enter move to the next and previous match.
  - Esc closes the bar.
- **Links.**
  - `http(s)` and `mailto` links open with `xdg-open`.
  - Relative `.md` links open in OmaRead in a new window, honouring any `#anchor`.
  - `#anchor` links scroll within the document.
  - Other local files open with `xdg-open`.
- **Copy.**
  - Normal text selection works within a block.
  - Right-click on a block, or Ctrl+Shift+C while hovering it, copies that block's source
    Markdown (from `srcStart`/`srcEnd`).
  - "Copy all" copies the whole file.
- **Zoom.** Ctrl + / Ctrl − / Ctrl 0 scale the reading typography only (not the chrome). Remember
  the zoom level across launches.
- **Keys.**
  - j / k and ↑ ↓ scroll.
  - Space / Shift+Space page.
  - g g / G go to the top and bottom.
  - Ctrl+W closes the window, q closes it too.
  - Ctrl+R reloads.
  - `?` shows a small shortcut sheet.
- **Recent files.** Keep the last 20 in `~/.local/state/omaread/recent.json`.
- **Motion.**
  - Content fades in on open (about 150 ms).
  - Scrolling to a heading is smooth.
  - Hover states ease.
  - Nothing bounces, nothing is slow.
  - Respect a reduced-motion env or setting if one exists in Omarchy's shell config.

## 6. Quality bar

- It must look **better than the Factory**. That is the explicit brief.
- Spacing comes from a consistent scale, as in the Factory's `Style.spacing`. Nothing sits a pixel
  off. Nothing is default-styled.
- It must look right in both **dark and light** themes. Test at least `gruvbox`, `tokyo-night`,
  `catppuccin-latte`, `rose-pine`, `flexoki-light` and `matte-black`, all under
  `~/.local/share/omarchy/themes/`.
- There must be no QML warnings or errors in the `qs` log when opening every sample. Treat warnings
  as bugs.
- A 5,000-line document opens in under a second and scrolls without dropped frames.
- Nothing crashes or goes blank on malformed input: unclosed fences, ragged tables, deep nesting, a
  huge single line, binary junk, or an empty file.

## 7. Process

1. **Scaffold** the app: the window, theme following, loading a file, and rendering paragraphs.
   Commit.
2. **Parser to blocks**, test-first (`test/`). Write unit tests for `lib/blocks.js` and
   `lib/inline.js` against the samples before building components. Tests must run headless from one
   command (`tools/test`).
3. **One block type at a time.** After each, run the screenshot tool and **look at the PNGs** with
   the Read tool. Iterate on the look until it is genuinely beautiful. Then commit.
4. **Window features** (§5), each with a manual check noted in the commit.
5. **Polish pass.** Re-screenshot every sample in all six themes and fix anything that looks off.
   Compare critically with the Factory.
6. **Write `README.md`**: what it is, the one install command, how to run, the keys, and how to make
   it the default `.md` app.

Commit small and often, with clear messages. End every commit message with:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

Record any significant decision, such as a font choice, the KSH theme mapping or the ListView
approach, in `docs/decisions/NNNN-title.md`, a few lines each.

Do not ask Keith questions for things this spec lets you decide: decide, record it, and keep going.
Stop and ask only if something is **impossible** as specified. In that case write a short note in
`docs/BLOCKED.md` with your options.

## 8. Samples and screenshots (how "beautiful" gets checked)

- `samples/` must contain at least:
  - `kitchen-sink.md`, with every block type in §4;
  - `prose.md`, several screens of real long-form prose;
  - `code.md`, with many languages, a long file, and a `diff` block;
  - `tables.md`, with narrow, wide and aligned tables;
  - `alerts.md`;
  - `frontmatter.md`;
  - `long.md`, with 5,000+ lines;
  - `malformed.md`.
- Also copy these real documents into `samples/real/`:
  - `~/projects/frontdesk/docs/adr/0003-calls-durable-from-pickup-actions-separate-from-speech.md`
  - `~/projects/frontdesk/docs/agentile/specs/fix-sign-out-menu-item/plan.md` (if it exists)
  - `~/projects/frontdesk-phone-agent/docs/research/holding-utterances.md`
  - this spec itself.

  These are the documents Keith actually reads.
- `tools/screenshot [sample…] [--themes a,b,…]` renders each sample under each theme to
  `shots/<theme>/<sample>-<n>.png` (gitignored). It does this at a fixed window size (1400×1000 and
  a narrow 800×1000), capturing the top and further pages by scrolling. Use `Item.grabToImage`
  inside the app behind a `--screenshot` env/flag. Try `QT_QPA_PLATFORM=offscreen` first; if
  Quickshell misbehaves offscreen, show real windows briefly and close them. Use
  `OMAREAD_THEME_DIR`, never Keith's real theme switch.
- Review shots with your own eyes (Read the PNGs) at every step. That review is the real test of
  this project.

## 9. Install (local)

- `bin/omaread` must work from anywhere: symlink it into `~/.local/bin`.
- `ops/omaread.desktop` contains:
  - `Name=OmaRead`
  - `Exec=<repo>/bin/omaread %f`
  - `MimeType=text/markdown;`
  - `Categories=Office;Viewer;`
  - an icon: design a simple SVG in `ops/omaread.svg`, a folded page with a reading line, in the
    Omarchy style.
- The README documents how to make it the default:

  ```
  xdg-mime default omaread.desktop text/markdown
  ```

  Do not run this yourself; Keith decides.

## 10. Done when

- Every sample renders beautifully in all six themes. The shots are committed under
  `docs/screenshots/`: pick the best 6–8, not all of them.
- All §5 behaviours work and have been checked by hand.
- Unit tests pass, and the `qs` log is clean.
- The README is written.
- `docs/REPORT.md` exists: what was built, what was decided, known gaps, and the 6–8 showcase
  screenshots linked.
