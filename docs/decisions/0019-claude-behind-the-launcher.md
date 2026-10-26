# 0019 Claude runs behind the launcher, with no tools

Date: 2026-10-26. Status: accepted.

## Decision

`Ctrl+J` in the editor opens an instruction line under a block, a section or a selection. The window writes a job file (the document, the range, the instruction and the earlier rewrites of that range) and runs `omarky rewrite --job FILE`. The Ruby launcher runs Claude Code headless (`claude -p`) with no tools, no settings, no MCP servers and no session history, and streams the rewrite back as JSON lines. The window never runs Claude itself.

Two optional files under `~/.config/omarky` shape every rewrite: a style guide (`writing.md`, or every Markdown file in `writing/`) added to the system prompt, and an executable `check` run on the rewrite. When the check exits non-zero, its report goes back to Claude once for another try.

## Why

This is the same boundary as git (decision 0013). The window's job is text and layout. Building a prompt, finding the `claude` binary, scrubbing the environment a nested Claude Code would inherit, and reading its stream are a few lines of Ruby with tests against a fake `claude`, and they would be awkward and untestable in QML.

Claude gets no tools because a rewrite needs none, and a tool-less run cannot touch the file or anything else on the machine. The window applies the result through the editor's own edit path, so `Ctrl+Z` takes it back like any other edit, and the file is saved the way it always is.

Claude Code bills the user's Claude subscription. There is no API key to configure and nothing to pay outside the subscription. A user without Claude Code installed never sees the line.

## Consequences

- A rewrite sends the whole document to Anthropic. The README says so beside the feature.
- The model is one constant in `launcher/omarky/rewrite.rb` (Opus 5.5 at low effort); `OMARKY_REWRITE_MODEL` overrides it.
- `OMARKY_CLAUDE` points the launcher at another `claude`, which is how the checks use a fake one.
- The editor's native module gained `replace(start, end, text)`, so a rewrite is one undo step. Without the module it is two.
