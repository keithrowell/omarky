# Rewrite with Claude

Status: design, for Keith's review. 26 October 2026.

## Recommendation

Put a rewrite instruction line into the editor itself, in the shared library, so OmarkyWriter and the reader's edit sheet get it from the same code. You select a block, a section or any run of text, press `Ctrl+J`, type what you want ("tighter, and drop the last sentence") and press `Enter`. Claude rewrites that range with the whole document as context, and the rewrite streams into a card under the range with the changed words marked, the way the reader marks changes between versions. `Enter` takes it into the text as one undo step, `Esc` leaves the text as it was, and typing another instruction refines the same rewrite.

The agent is Claude Code run headless (`claude -p`) by the Ruby launcher, with no tools, on your subscription. The window never runs Claude itself, for the same reason it never runs git (decision 0013). Your writing rules go to Claude with every rewrite, and your checker runs on what comes back before you see it.

## What you see

```
  ## Principles

  ┌───────────────────────────────────────────────────────────┐
  │ A printed page is the work of centuries of craft. Its     │  the range, on a soft
  │ measure, its margins, the space between its lines ...     │  shade of the page colour
  └───────────────────────────────────────────────────────────┘
  ✦ shorter, and keep the hour line                     ⏎

  ┌ Claude ───────────────────────────────────────────────────┐
  │ A printed page is centuries of craft: its measure, its    │  added words on the green
  │ margins, the space between its lines. When a page is set  │  wash, removed words struck
  │ well, you start reading and an hour has passed.           │  in red, as in changes mode
  │                                     Enter use · Esc drop  │
  └───────────────────────────────────────────────────────────┘
```

The range takes a shade of the page colour, with no accent bar. The instruction line sits under it in the reading font, in the column, at the measure of the text. While Claude works, the card fills as the text streams in, and a quiet line under it says "Writing…" with `Esc` to stop.

## Choosing the range

| Keys | Range |
|---|---|
| `Ctrl+J` with a selection | The selection, widened to whole words |
| `Ctrl+J` with no selection | The block the cursor is in: a paragraph, a list, a quote, a table or a code block |
| `Ctrl+Shift+J` | The section the cursor is in, from its heading to the next heading of the same or a higher level |
| `Ctrl+J` again, on the line | Widens the range one step: selection, block, section, whole document |

Blocks and sections come from the parser the reader already uses, so a block in the writer is exactly what the reader calls a block. The section rule is the reader's `Shift+E` rule, moved from the reader's window into the library.

## The conversation on a range

Each range holds a short conversation until you take or drop the rewrite. A second instruction ("good, but less formal") goes to Claude with the first instruction and the rewrite it produced, so you refine rather than start again. `Alt+Up` and `Alt+Down` step back through the rewrites of this conversation in the card. Taking a rewrite ends the conversation. The instructions you type are remembered across sessions, and `Up` on an empty line recalls them, so "tighten this" or "Australian English" is two keys.

## Taking the rewrite

`Enter` on the card replaces the range through the editor's own edit path, as a single step, so `Ctrl+Z` puts the original back and the file saves the way it always does. You can keep writing elsewhere in the document while Claude works. When you take the rewrite, the editor finds the range by its original text near its original place. If you changed the range itself in the meantime, the card says so and offers the rewrite to copy, and nothing is written over.

In the reader's edit sheet the line sits in the space left under the editor for it. Taking the rewrite puts it into the sheet's editor, and `Ctrl+Enter` writes the file as it does now. The sheet's rule against writing over a change from elsewhere still holds.

## The agent

The launcher gets one JSON job on standard input from a new subcommand, `omarky rewrite`, and streams the rewrite back as lines of JSON. The window reads the stream through a `Process`, as it reads `--versions` today.

| Part | What it is |
|---|---|
| Command | `claude -p --output-format stream-json --include-partial-messages --verbose` |
| Tools | None (`--tools ""`), so Claude can only write text back |
| Model | Opus 5.5 at low effort; `--model` is one constant in the launcher |
| Context | The whole document, with the range marked, the file's name, the instruction and the earlier turns on this range |
| Writing guide | The file at `~/.config/omarky/writing.md` if it exists, appended to the system prompt |
| Checker | The executable at `~/.config/omarky/check` if it exists, run on the rewrite; any line it reports goes back to Claude once for a corrected rewrite before the card settles |
| Session | `--no-session-persistence`; each turn sends the conversation again, so nothing piles up in your Claude history |

The system prompt tells Claude to return only the replacement Markdown for the range, to keep the document's voice and spelling, and to change nothing the instruction does not ask for. Anything else Claude says is dropped, and an empty or unchanged reply shows as "No change" in the card.

On your machine, `ops/install` links the writing guide to your writing skill and the checker to its `check.rb`, so a rewrite in the writer meets the same rules as anything I write for you. For anyone else the two files are optional, and the feature works without them.

The line only appears when `claude` is on the path. Without it, `Ctrl+J` does nothing and the help sheet does not list it.

## Cost and privacy

A rewrite sends the whole document to Anthropic through Claude Code and bills your Claude subscription, the same as OmaBlog's assist runs. There is no API key and no spend outside the subscription. The README says this plainly under the feature, so a stranger installing Omarky knows a document leaves the machine when they press `Enter` on the line.

## Building and testing

- **Library:** range finding (selection, block, section, widening) in `lib/editing.js`, with QML tests over the samples.
- **Library:** the instruction line and the card as one component beside the editor, used by the writer window and by the reader's edit sheet.
- **Launcher:** `omarky rewrite` in Ruby, with a minitest suite that runs it against a fake `claude` script emitting a recorded stream (partial chunks, a final message, an error, a checker round).
- **Checks:** `writer/tools/check` and `reader/tools/check-sheet` gain runs against the same fake: open the line, send, stream, take, undo, and the changed-range refusal.
- **Docs:** a decision record for keeping Claude behind the launcher, the README section and the site section, and the new keys in both help sheets.

## Out of scope

Asking Claude a question about the text without a rewrite, rewriting several ranges in one go, giving Claude tools such as web search, and suggestions that appear without being asked for. Each can come later on the same launcher command.
