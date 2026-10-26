# OmaChanges: a document diff reader for Omarchy

Status: approved design, 25 October 2026. Brainstormed with Keith over four mockup screens, kept under `.superpowers/brainstorm/` in this repository.

OmaChanges opens a Markdown document and shows how it differs from an earlier version of itself, set the way OmaRead sets a page. You read the document as it is now. Added words sit on a tinted wash, removed words stay where they were, struck through and faded, and the margin says what happened to each paragraph. Versions are people and times, never commits. The usual way in is a sentence to Claude: "show me the diff between this and Danny's version".

## 1. Purpose

Keith reviews documents other people have edited, and documents he edited himself over several days: proposals, statements of work, specs, workshop reports. The question is nearly always "what changed in this section since Danny touched it" or "what changed across the whole document since I sent it". The tools to hand answer a different question. `git diff` and Changes.app show lines of Markdown source, so a hard-wrapped paragraph with one new word shows as a whole paragraph removed and another added, and nobody can read a proposal as a diff of its source.

OmaChanges answers the question in the document's own terms:

- The reading column is OmaRead's, so a changed document is as readable as an unchanged one.
- Differences are found paragraph by paragraph and then word by word, so a reworded sentence shows its reworded words.
- The two ends of the comparison are named as a person and a time, with the check-in message as a plain sentence, and chosen from a list or by a phrase.
- A fold hides everything that did not change, so one scroll covers a long document.

### Non-goals for the first release

- Editing, or accepting and rejecting changes. OmaChanges reads.
- Versions from anywhere but the file's git history. Dropbox revisions, a history the Oma apps keep for themselves, and comparing two arbitrary files all wait, and section 5 shapes the version provider so they slot in.
- Detecting a paragraph that moved. It shows as removed in one place and added in another.
- The timeline strip from the brainstorm (screen 2, option A). The list from the pill was chosen instead.
- Change counts beside each row of the version list. Git's line counts mislead on wrapped prose, and paragraph counts need a diff per row.
- Files other than Markdown. Plain text opens and is treated as paragraphs separated by blank lines. Anything else is refused with a sentence.
- Comparing branches, since a version is a check-in that touched this file.

## 2. Terms

| Term | Meaning |
|---|---|
| Version | The text of the file at one moment: a check-in that touched it, or the file on disk now |
| Now | The file as it is on disk, saved or not, committed or not |
| From, to | The two ends of a comparison. The window reads "to compared with from". To defaults to Now |
| Check-in | A git commit that touched the file, shown as who, when and the commit message |
| Block | One top-level unit of the document in OmaRead's block model: a paragraph, heading, list, table, code block and so on |
| Pair | A block in from and a block in to that the engine decided are the same block, changed |
| Change | A block that is added, removed or paired with differences. A list counts one change per changed item |

## 3. Stack and constraints

OmaChanges is a sibling of OmaRead and OmaWriter and is built the same way:

- QML on Quickshell, no web view. Window class `omachanges`.
- OmaRead's renderer, theme service and shell components vendored under `vendor/omaread/` at the commit recorded in `vendor/omaread/REVISION`, copied by `tools/vendor` from `~/projects/omaread`. This is OmaWriter's arrangement.
- The change marks are an upstream addition to OmaRead's `MarkdownView` (section 7), so the vendored copy is unmodified and OmaWriter can show changes later with no further work.
- The launcher and version resolver are Ruby, run on `/usr/bin/ruby` so opening a document never depends on mise or on the directory it is opened from. WebReader's handler set this precedent.
- Git is reached through the `git` command. Nothing links against libgit2.
- Fonts, colours and motion follow OmaRead: iA Writer Quattro S and Mono S, the current Omarchy theme live, reduced motion when Hyprland animations are off.
- State in `~/.local/state/omachanges/` (log, recent comparisons). Runtime files (the lock, job files) in `$XDG_RUNTIME_DIR/omachanges/`.

The repository is `~/projects/omachanges`, public on GitHub once the first release is tagged, under the same licence as OmaRead.

## 4. Repository layout

```
bin/omachanges              Ruby launcher: resolve versions, write a job, hand it to the window
lib/omachanges/             Ruby: history.rb (git), resolver.rb (phrases to check-ins), job.rb
lib/diff/                   JavaScript, .pragma library: tokens.js, words.js, align.js, changes.js
shell.qml                   Quickshell root: one process, IPC, windows
ui/                         ChangesWindow, Header, VersionPill, VersionList, ChangeOutline, FoldRow, Banner
vendor/omaread/             OmaRead at REVISION (renderer, services, Commons, Ui, markdown-it)
test/                       tst_*.qml for lib/diff, Ruby minitest for lib/omachanges
tools/test, tools/check, tools/shot, tools/vendor
ops/install, ops/omachanges.desktop, ops/omachanges.svg
samples/                    Pairs of versions and a script that builds a sample git history
docs/superpowers/specs/     This document
docs/decisions/             Numbered decision records
```

## 5. The launcher and version resolution

### Command line

```
omachanges FILE [--from SPEC] [--to SPEC]
omachanges FILE --list            print the file's versions as the window would show them
omachanges FILE --resolve SPEC    print one version as JSON (the window calls this)
omachanges --foreground …         run qs in this terminal (development)
omachanges --version
```

With no `--from`, from is the most recent version whose text differs from to. Opening a file with no flags therefore shows your uncommitted work against the last check-in, or, when the file is clean, the last check-in against the one before it. With `--to` and no `--from`, from is the check-in just before to, so `--to "danny fri"` shows what Danny did on Friday.

### What a spec resolves to

| Spec | Resolves to |
|---|---|
| `now` | The file on disk |
| `danny`, `keith`, `me` | That person's most recent check-in of the file, before to when to is a check-in. `me` is `git config user.name`. Matching is on the author name, case-insensitive, and a first name is enough |
| `yesterday`, `today`, `3 days ago`, `a week ago`, `last week`, `mon`, `friday`, `23 oct`, `2026-10-23` | The last check-in at or before the end of that day. A bare weekday is the most recent one before today. The version as the file stood at the end of that day, so comparing Now with `yesterday` shows what changed today |
| `danny fri`, `keith 23 oct` | That person's last check-in on or before that day |
| `sent` | The check-in at or before the end of the day named in `SENT.md` in the file's directory. The first date in that file counts, in ISO or "23 October 2026" form. Absent file, absent date: an error sentence |
| `before X` | The check-in just before whatever X resolves to |
| A SHA, `HEAD~2`, a tag, a branch | Passed to git. Shown in the window as the person and time of that commit all the same |

Resolution runs over `git log --follow` for the file, with author, author date, subject and body. Commit dates use the author date in local time. When a spec matches nothing, the launcher still opens the window, with the document rendered plain, a banner saying what was not found (section 8), and the version list ready. A terminal error is reserved for a missing file or a file outside any git work tree when a spec other than `now` was asked for.

### Handing the window a job

The launcher writes a JSON job to `$XDG_RUNTIME_DIR/omachanges/jobs/<id>.json` and sends the path over IPC (`qs ipc call omachanges open <path>`), starting the process first if none holds the lock. A job holds:

- The document path and whether it is inside a git work tree.
- `from` and `to`, each with: text, a label (`Now` or the person's name), the author's full name, the time, the commit subject and body, and the SHA (kept only for the window to pass back).
- The history: every check-in of the file, newest first, with the same fields minus the text.
- The shortcuts the list should offer: one per author in the history other than the current user ("Danny's last edit"), "my last edit", "yesterday", "a week ago", and "when it was sent" when `SENT.md` has a date.

When a selection in the window needs a version it does not have, the window runs `omachanges FILE --resolve SPEC` through a Quickshell `Process` and reads the JSON from stdout. The window never runs git itself. That boundary is the version provider: a second provider later (Dropbox, a kept history, a second file) changes the Ruby side only.

## 6. The diff engine

`lib/diff/` takes two Markdown strings and returns the to document's blocks with changes marked, plus counts. It is pure JavaScript in OmaRead's `.pragma library` style, built on the vendored `blocks.js` and `inline.js`, and tested headless with qmltestrunner like OmaRead's own libraries.

### Steps

1. Parse both texts with `Blocks.build`. Each side is a flat list of top-level blocks with nested children.
2. Cut each side into sections at headings. Align sections by heading slug with a longest common subsequence. An unmatched heading pairs with an unmatched heading of the same level on the other side when their word similarity is at least 0.6, which keeps a retitled section together.
3. Within each aligned section, align blocks. First an exact pass: a longest common subsequence over blocks whose normalised plain text (whitespace collapsed, case kept) is identical. Then a pairing pass over what is left: a removed block and an added block of the same type pair, in order, when their similarity is at least 0.5. Similarity is the Dice coefficient over word tokens. Anything still unmatched is removed or added.
4. Inside a pair, a word-level diff over the plain text of the runs. Tokens are words, punctuation marks and whitespace; whitespace tokens never count as a difference on their own. The algorithm is Myers' O(ND) over tokens. Differences are mapped back onto the runs by character offset, splitting runs where a difference starts or ends, and the pair's runs become one merged sequence: from-only runs flagged `del`, to-only runs flagged `ins`, shared runs plain, in diff order. Style flags on a shared run come from the to side.
5. Structured blocks align inside themselves. List items align like blocks (exact, then similarity), and each item's children recurse. Table rows align by first cell, then by position, and cells take the word diff. Code and diff blocks diff by line, with lines flagged `ins` or `del`. An image whose source changed is removed plus added. Front matter diffs field by field. A rule is a rule.
6. The output is the to document's blocks in order, with removed blocks inserted where they stood relative to their neighbours. Every top-level block and list item carries `change`: `same`, `added`, `removed` or `reworded`. Each heading carries the count of changes in its section including subsections, for the outline. The engine also returns the total.

### Behaviour at the edges

- An empty from (the file did not exist at that version) marks every block added.
- Two identical texts return every block `same` and a total of zero.
- A paragraph split into two, or two joined, pairs the larger overlap and leaves the remainder added or removed. The release does not try harder.
- A long document (20 000 words) diffs within 200 ms on the laptop. Token diffs run per pair, so cost is near-linear in document length.

### Tests

Pairs of Markdown strings in `test/tst_diff.qml` with the expected marks: a reworded sentence, an added paragraph, a removed paragraph, a renumbered list, a retitled section, a table cell, a code block line, a split paragraph, an empty side, identical sides, and hard-wrapped source re-wrapped with no words changed, which must report zero changes.

## 7. Rendering: the OmaRead addition

OmaRead's `MarkdownView` gains one optional input, `changes`, inert when null. The addition lands upstream in `~/projects/omaread` with its own tests, and OmaChanges vendors the commit that has it. The pieces:

- `services/Doc.qml` takes its blocks from `changes.blocks` when set, instead of parsing `markdown`.
- `lib/inline.js` paints runs flagged `ins` and `del`. An inserted run sits on a wash, the theme's green flattened onto the page at 0.26 in dark themes and 0.22 in light, with a 3 px radius drawn by `RichText.qml` the way code chips are. A deleted run is struck through in the theme's red at 0.85 and set in the faint text colour.
- `components/Block.qml` reads `block.change`. A reworded block draws its word in the gutter to the left of the column, in caption size and the faint colour, where list bullets hang: "reworded", "added" in green, "removed" in red. An added block gets a soft wash across the whole block (green at 0.10, rounded) instead of word marks. A removed block is struck through whole in the faint colour.
- Tables wash changed cells. Code blocks band changed lines with the green and red bands OmaRead already draws for diff fences.
- Find searches the visible text, struck runs included. Copying a block copies the to text only.

All colours derive from the theme the way OmaRead's do, so a theme switch repaints the marks live. Nothing is a hard-coded red or green.

## 8. Window and behaviour

### Process and windows

One background process owns every window, holds a lock in `$XDG_RUNTIME_DIR/omachanges/`, and takes jobs over IPC. A second `omachanges FILE` hands the job over and opens a new window at once. A window's title is "OmaChanges: FILE". Logs go to `~/.local/state/omachanges/qs.log`.

### The bar

Left: the file name in bold and its directory in mono, as OmaRead. Centre right: the version pill, reading "Now compared with (D) Danny Thu 23 Oct", with a disc of the author's initial. Then the change total ("14 changes"). Then the icons: find, fold, outline, shortcuts help. The thin progress line along the top edge stays.

### The version list

Clicking the pill drops a list under it (brainstorm screen 3). A shortcuts row of chips comes first, from the job. Then the history, newest first, one row per check-in: the author's disc, their first name, the time as "Sat 25 Oct, 9:40 am", and the commit subject on its own line beneath, cut with an ellipsis when it overruns. Resting on a row for 400 ms opens a card under it with the subject in full, the body text, and the author's full name and long date. Clicking a row sets from and closes the list. The current from row is shaded. The list's foot offers "Compare two past versions…", which makes the next click set to and the one after set from, with the pill reading "(K) Keith Fri 24 Oct compared with (D) Danny Thu 23 Oct". Esc closes the list.

Author discs take a colour from the theme's green, blue, yellow, magenta and cyan by a stable hash of the author name, so Danny is the same colour in every document. Now has an outlined disc with no letter.

### Reading

Everything OmaRead gives a reader stays: the outline, find, copy, zoom, the progress line, keeping your place when the file changes. The outline shows each heading's change count in mono at the right, and dims headings whose count is zero.

The fold (key `f`, and the icon) collapses every run of unchanged top-level blocks between changes into one hairline row: "3 paragraphs unchanged", or "3 blocks unchanged" when the run is not all paragraphs. Headings stay. A section with no changes collapses to its heading, dimmed, with "unchanged" beside it. Clicking a row opens that run in place; `f` again opens everything. The fold state is remembered per window, and the default for new windows is a preference, off to begin with.

`n` and `p` move to the next and previous change and settle it a third of the way down the window, with the block briefly tinted the way a find match is revealed.

When to is Now, the window watches the file. A change on disk re-runs the diff and keeps the reader's place, so OmaChanges sits beside OmaWriter and follows the edit.

### Banners

A strip under the bar, in OmaRead's banner style, for the states where there is nothing to compare:

| State | Banner |
|---|---|
| File outside any git work tree | "This file is not in a git repository, so it has no earlier versions." The document renders plain. |
| Author spec matched nobody | "Danny has no check-ins of this file." The list opens. |
| Day spec before the file existed | "The file did not exist yet on 3 October." The list opens. |
| From and to identical | "No changes since Danny, Thu 23 Oct." |
| `SENT.md` missing or dateless | "There is no sent date in this directory." The list opens. |

### Keys

| Key | Does |
|---|---|
| `j` `k` `↓` `↑`, `Space`, `Shift+Space` | Scroll, as OmaRead |
| `n` `p` | Next and previous change |
| `f` | Fold and unfold the unchanged |
| `v` | Open the version list |
| `o` | Outline |
| `/` | Find |
| `Ctrl+=` `Ctrl+−` | Zoom |
| `?` | Shortcut sheet |
| `Esc` | Close the list, the find bar, or the window |

## 9. The Claude skill

`~/.claude/skills/omachanges/SKILL.md`, in the shape of open-in-omaread. Triggers: "show me the diff", "what changed in X since Y", "compare this with Danny's version", "show me Danny's changes", "open it in OmaChanges". Steps:

1. Resolve the document to an absolute path the way open-in-omaread does: a name, "this", or the file under discussion.
2. Turn the phrase into `--from` and `--to` using the table in section 5. "Since yesterday" is `--from yesterday`. "Danny's changes on Friday" is `--from "before danny fri" --to "danny fri"`. "Since we sent it" is `--from sent`.
3. Launch through `claude-here omachanges PATH --from SPEC` so the window lands on the session's workspace.
4. Confirm the window by its title in `hyprctl clients -j`, and on failure read the tail of the log and say what failed.
5. Tell Keith in one line what is open and against which version.

For a question with no window wanted ("who last changed this"), the skill runs `omachanges FILE --list` and answers from that.

## 10. Install

```
sudo pacman -S --needed quickshell ttf-ia-writer git ruby
~/projects/omachanges/ops/install
```

The script links `omachanges` into `~/.local/bin`, adds the desktop entry and icon, and leaves the default Markdown app alone. `tools/vendor [COMMIT]` refreshes `vendor/omaread/` from `~/projects/omaread` and writes `REVISION`.

## 11. Quality bar and testing

- `tools/test` runs the qmltestrunner suites for `lib/diff` and the Ruby minitest suite for the resolver. The resolver tests build a throwaway repository with scripted commits from two authors on fixed dates, so "danny fri" and "sent" are checked against known answers.
- `tools/check` drives an offscreen window through IPC: open a sample pair, assert the change total, toggle the fold, select a version from the list, rewrite the file on disk and assert the diff re-ran, and finish with a clean log. OmaWriter's `tools/check` is the model.
- `tools/shot` screenshots a comparison under any theme for the README. Screenshots in six themes, light and dark, are part of done.
- Samples are industry-neutral, so no client name, number or situation from `~/agenta/clients/` appears in `samples/` or in a screenshot.
- The log is clean after every check, under the same two suppressed Qt rules OmaRead uses.

## 12. Later work

Recorded so the design leaves room, none of it in the first release:

- A paragraph that moved shows as moved, with a gutter word and a link to where it went.
- Comparing two arbitrary files, and versions from Dropbox or from a history the Oma apps keep when a file is saved, each as another version provider behind the `--resolve` boundary.
- The timeline strip as a panel the version list can open.
- Change counts in the version list, computed lazily by the engine for the rows on screen.
- Exporting the marked-up document as CriticMarkup, which Sakusei could render to a PDF of the changes for a client.
- Accepting a change into OmaWriter.

## 13. Done when

- `omachanges proposal.md --from danny` opens a window within a second on a document already in a repository, reading as view A of the brainstorm in the current theme.
- The fold, the version list with its hover cards, next and previous change, the outline counts and the banners all work as sections 7 and 8 describe.
- A re-wrapped paragraph with no words changed reports zero changes, and the word-level test pairs in section 6 pass.
- The resolver tests pass for every row of the spec table in section 5.
- `tools/check` passes with a clean log, and the README shows six themed screenshots.
- The Claude skill opens a comparison from a sentence and lands the window on the session's workspace.
- OmaRead upstream has the `changes` input merged with tests, and `vendor/omaread/REVISION` points at that commit.
