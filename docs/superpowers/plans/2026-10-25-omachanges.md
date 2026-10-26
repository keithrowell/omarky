# OmaChanges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Quickshell app that opens a Markdown file and shows it as it is now against an earlier git version of itself, in OmaRead's column, with word-level change marks, a version list named by people and times, a fold that hides the unchanged, a Ruby launcher and a Claude skill.

**Architecture:** OmaRead is vendored as a git submodule and gains an optional `changes` input on `MarkdownView` plus the run marks, gutter words and fold row that paint a changed document. OmaChanges adds a pure JavaScript diff engine (parse both texts with OmaRead's block model, align sections and blocks, word-diff each pair), a Ruby launcher that resolves phrases such as `danny` or `yesterday` against `git log --follow` and hands the window a JSON job, and QML for the window chrome (version pill and list, outline counts, banners, keys).

**Tech Stack:** Quickshell (QML, Qt 6), JavaScript `.pragma library` modules tested with `qmltestrunner`, Ruby on `/usr/bin/ruby` tested with minitest, git CLI, iA Writer fonts, Omarchy theme files.

**Spec:** `docs/superpowers/specs/2026-10-25-omachanges-design.md`

## Global Constraints

- Window class and IPC target are `omachanges`; the lock lives at `$XDG_RUNTIME_DIR/omachanges/<instance>.lock`, state at `~/.local/state/omachanges/`, jobs at `$XDG_RUNTIME_DIR/omachanges/jobs/`.
- The launcher runs on `/usr/bin/ruby` with no gems outside the standard library.
- The vendored OmaRead is never edited in `vendor/omaread`. Changes to the renderer are commits in `~/projects/omaread`, then the submodule pointer moves.
- Versions are shown as a person and a time. No SHA, ref or branch appears in the window.
- Every colour derives from the theme through `Theme` (`Theme.green`, `Theme.red`, `Theme.flat`, `Theme.mix`). No literal colours in QML or JS.
- Samples and screenshots are industry-neutral: nothing from `~/agenta/clients/`.
- Prose in README, skill and decision records follows `~/.claude/skills/writing/SKILL.md`. Code comments and commit subjects are exempt.
- JS libraries are `.pragma library` files using `.import "x.js" as X`, ES5 style (`var`, `function`), as OmaRead's are. Tests are `test/tst_*.qml` run by `tools/test`.
- Commit after each task, in the repository the task touches (`~/projects/omaread` for Tasks 2 to 4, `~/projects/omachanges` otherwise).

## File structure

OmaRead (upstream, `~/projects/omaread`):

| File | Change |
|---|---|
| `lib/blocks.js` | `index(blocks)` returns `{ headings, anchors, pieces }`; `build` uses it |
| `lib/inline.js` | Runs may carry `ins` or `del`; `toHtml` sets the faint colour on `del`; `markRanges(runs)` lists mark spans in document positions |
| `services/Reading.qml` | `tones.ins`, `tones.del` |
| `services/Doc.qml` | `adopt(doc)` installs a prepared block document, with the reload signals |
| `components/MarkdownView.qml` | `property var changes`, `signal unfoldRequested(int index)`, `ctx.unfold(index)` |
| `components/RichText.qml` | Draws ins washes behind and del strikes over the text, from `markRanges` |
| `components/DocView.qml` | Gutter word and added wash per top-level block from `block.change` |
| `components/blocks/ListBlock.qml` | Gutter word per item from `item.change` |
| `components/blocks/Fold.qml` | New: "N paragraphs unchanged" row, and the dimmed heading variant |
| `components/Block.qml` | Registers `fold` |
| `test/tst_inline.qml`, `test/tst_blocks.qml` | Tests for the above |

OmaChanges (`~/projects/omachanges`):

| File | Responsibility |
|---|---|
| `vendor/omaread` | Submodule |
| `ui/{Commons,components,lib,services,Ui,vendor}` | Symlinks into the submodule so `qs.*` imports resolve |
| `ui/shell.qml` | Process root: lock, IPC, job intake, windows |
| `ui/app/ChangesWindow.qml` | One comparison: header, outline, column, banners, keys, file watch |
| `ui/app/ChangesHeader.qml` | Bar: file, version pill, count, icons |
| `ui/app/VersionList.qml` | Popover from the pill: shortcuts, history rows, hover card |
| `ui/app/ChangeOutline.qml` | Outline with per-heading counts |
| `ui/app/HelpSheet.qml` | Key sheet |
| `ui/app/Comparison.qml` | Holds the job, runs the engine, exposes `document`, `total`, labels |
| `lib/diff/words.js` | Tokens, Myers diff, segments, similarity |
| `lib/diff/runs.js` | Segments onto runs: `markRuns(fromRuns, toRuns)` |
| `lib/diff/align.js` | LCS alignment and non-crossing similarity pairing |
| `lib/diff/changes.js` | `compare(fromText, toText)` and `document(result)` |
| `lib/diff/fold.js` | `fold(blocks, open)` collapses unchanged runs |
| `lib/omachanges/history.rb` | Git log and show for one file |
| `lib/omachanges/resolver.rb` | Spec phrases to versions |
| `lib/omachanges/job.rb` | Job JSON and shortcuts |
| `lib/omachanges/cli.rb` | Argument parsing, launch, `--list`, `--resolve` |
| `bin/omachanges` | Ruby entry point |
| `test/tst_words.qml`, `test/tst_runs.qml`, `test/tst_align.qml`, `test/tst_changes.qml`, `test/tst_fold.qml` | Engine tests |
| `test/ruby/*_test.rb`, `test/ruby/fixture_repo.rb` | Resolver tests over a scripted repository |
| `tools/test`, `tools/check`, `tools/shot` | Test runner, offscreen end-to-end check, screenshot |
| `ops/install`, `ops/omachanges.desktop`, `ops/omachanges.svg` | Install |
| `samples/`, `samples/make-repo` | Sample pairs and a script that builds a sample history |
| `~/.claude/skills/omachanges/SKILL.md` | The Claude skill |

### Task 1: Repository scaffold that renders a file plainly

**Files:**
- Create: `.gitmodules`, `vendor/omaread` (submodule), `ui/Commons` … `ui/vendor` (symlinks), `ui/shell.qml`, `ui/app/ChangesWindow.qml`, `ui/app/qmldir`, `bin/omachanges`, `lib/omachanges.rb`, `lib/omachanges/cli.rb`, `tools/test`, `VERSION`, `LICENSE`, `.gitignore`

**Interfaces:**
- Produces: `bin/omachanges FILE` opens a window rendering FILE through the vendored `MarkdownView`. `OMACHANGES_OPEN` carries job file paths (one per line) to a fresh `qs`. IPC `omachanges open <jobpath>`, `count`, `state n`, `key n spec`, `shot n path`, `close n`.

- [ ] **Step 1: Add the submodule and symlinks**

```bash
cd ~/projects/omachanges
git submodule add https://github.com/keithrowell/omaread.git vendor/omaread
git -C vendor/omaread remote add local ~/projects/omaread
mkdir -p ui/app
for d in Commons components lib services Ui vendor; do ln -s ../vendor/omaread/$d ui/$d; done
echo 0.1.0 > VERSION
cp ~/projects/omaread/LICENSE LICENSE
printf '.superpowers/\n/build/\n' > .gitignore
```

- [ ] **Step 2: Write the Ruby entry point and a first CLI**

`bin/omachanges`:

```ruby
#!/usr/bin/ruby
# OmaChanges: a document diff reader for Omarchy.
#
#   omachanges FILE [--from SPEC] [--to SPEC]   open FILE compared with an earlier version
#   omachanges FILE --list                      print the file's versions
#   omachanges FILE --resolve SPEC              print one version as JSON
#   omachanges --foreground …                   run qs in this terminal (development)
#   omachanges --version
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "omachanges"
exit OmaChanges::CLI.new(ARGV, root: File.expand_path("..", __dir__)).run
```

`lib/omachanges.rb`:

```ruby
require "json"
require "time"
require "date"
require "fileutils"
require "shellwords"
require_relative "omachanges/cli"
```

`lib/omachanges/cli.rb` (first version: no git yet, a job with `now` on both sides so the window renders the file):

```ruby
module OmaChanges
  class CLI
    def initialize(argv, root:)
      @argv = argv.dup
      @root = root
      @state = ENV["OMACHANGES_STATE_DIR"] || File.join(ENV["XDG_STATE_HOME"] || File.join(Dir.home, ".local/state"), "omachanges")
      @runtime = File.join(ENV["XDG_RUNTIME_DIR"] || "/tmp", "omachanges")
      @instance = ENV["OMACHANGES_INSTANCE"] || "omachanges"
    end

    def run
      return help if @argv.include?("-h") || @argv.include?("--help")
      return version if @argv.include?("-V") || @argv.include?("--version")
      foreground = @argv.delete("--foreground")
      file = @argv.shift or return help
      path = File.expand_path(file.sub(%r{\Afile://}, ""))
      return error("#{file}: no such file") unless File.file?(path)
      text = File.read(path)
      job = { "path" => path, "inRepo" => false,
              "from" => { "label" => "Now", "text" => text }, "to" => { "label" => "Now", "text" => text },
              "history" => [], "shortcuts" => [] }
      open_job(write_job(job), foreground: foreground)
    end

    private

    def write_job(job)
      dir = File.join(@runtime, "jobs")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "#{Time.now.strftime('%Y%m%d-%H%M%S')}-#{Process.pid}.json")
      File.write(path, JSON.generate(job))
      path
    end

    def lock_path = File.join(@runtime, "#{@instance}.lock")

    # A running instance takes the job over IPC; otherwise start qs.
    def open_job(job_path, foreground: false)
      if (pid = running_pid)
        return 0 if system("qs", "ipc", "--pid", pid, "call", "omachanges", "open", job_path, out: File::NULL, err: File::NULL)
      end
      FileUtils.mkdir_p(@state)
      env = { "OMACHANGES_OPEN" => job_path,
              "XDG_DATA_DIRS" => "#{Dir.home}/.local/share/omaread/ksh:#{ENV['XDG_DATA_DIRS'] || '/usr/local/share:/usr/share'}" }
      args = ["qs", "--log-rules", "qt.qml.usedbeforedeclared=false;qt.qpa.services.warning=false", "-p", File.join(@root, "ui/shell.qml")]
      if foreground
        exec(env, *args)
      else
        log = File.open(File.join(@state, "qs.log"), "w")
        Process.detach(spawn(env, *args, pgroup: true, in: File::NULL, out: log, err: log))
      end
      0
    end

    def running_pid
      return nil unless File.file?(lock_path)
      pid = File.read(lock_path).strip
      return nil if pid.empty?
      Process.kill(0, pid.to_i) ? pid : nil
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    def help
      puts File.readlines(File.join(@root, "bin/omachanges")).grep(/^#/).drop(1).map { |l| l.sub(/^# ?/, "") }
      0
    end

    def version
      puts "omachanges #{File.read(File.join(@root, 'VERSION')).strip}"
      0
    end

    def error(msg)
      warn "omachanges: #{msg}"
      2
    end
  end
end
```

`chmod +x bin/omachanges`.

- [ ] **Step 3: Write the shell and a first window**

`ui/shell.qml` follows OmaRead's `shell.qml` (lock Process, hand-off Process, Instantiator, IpcHandler) with these differences: `//@ pragma AppId omachanges`, lock path under `omachanges/`, env `OMACHANGES_OPEN` and `OMACHANGES_INSTANCE`, IPC target `omachanges`, `open(jobPath)` appends `{ wid, jobPath }` and the window loads the job. Keep `count`, `state`, `key`, `shot`, `close`. Drop `link`, `hover`, `bench`.

`ui/app/qmldir`:

```
module qs.app
ChangesWindow 1.0 ChangesWindow.qml
```

`ui/app/ChangesWindow.qml`, first version:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.services
import qs.components as OmaRead

FloatingWindow {
  id: win
  property string jobPath: ""
  property var job: null
  readonly property string path: job ? job.path : ""
  readonly property string fileName: path ? path.split("/").pop() : ""
  readonly property Item grabRoot: page
  signal closeRequested()

  title: fileName ? "OmaChanges: " + fileName : "OmaChanges"
  implicitWidth: Style.space(1180)
  implicitHeight: Style.space(900)
  color: Theme.bg

  FileView {
    path: win.jobPath
    blockLoading: true
    onLoaded: win.job = JSON.parse(text())
    onLoadFailed: console.error("OmaChanges: cannot read job " + win.jobPath)
  }

  function debugState() {
    return { title: title, path: path, loaded: md.doc.loaded, blocks: md.doc.blocks.length }
  }
  function sendKey(spec) { }

  FocusScope {
    id: page
    anchors.fill: parent
    focus: true
    Rectangle { anchors.fill: parent; color: Theme.bg }
    OmaRead.MarkdownView {
      id: md
      anchors.fill: parent
      markdown: win.job ? win.job.to.text : ""
      baseUrl: win.path ? win.path.slice(0, win.path.lastIndexOf("/")) : ""
      documentName: win.fileName
    }
  }
}
```

- [ ] **Step 4: Write `tools/test`**

```bash
#!/usr/bin/env bash
# JS unit tests (test/tst_*.qml) under Qt's V4 engine, then the Ruby tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1
export QT_LOGGING_RULES="qt.qml.usedbeforedeclared=false"
if ls test/tst_*.qml >/dev/null 2>&1; then
  /usr/lib/qt6/bin/qmltestrunner -input test "$@"
fi
if ls test/ruby/*_test.rb >/dev/null 2>&1; then
  for t in test/ruby/*_test.rb; do /usr/bin/ruby -I lib -I test/ruby "$t"; done
fi
```

- [ ] **Step 5: Run it offscreen and check the window renders**

```bash
cd ~/projects/omachanges
export OMACHANGES_INSTANCE=dev-$$ QT_QPA_PLATFORM=offscreen
bin/omachanges --foreground ~/projects/omaread/samples/prose.md &
pid=$!; sleep 2
qs ipc --pid $pid call omachanges state -1
kill $pid
```

Expected: JSON with `"loaded":true` and a block count above zero. Fix any import error before going on.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Scaffold: submodule, launcher, shell and a plain-rendering window"
```

### Task 2: OmaRead: a prepared document in, run marks out

Work in `~/projects/omaread` on `main`.

**Files:**
- Modify: `lib/blocks.js` (`build`, new `index`), `lib/inline.js` (`toHtml`, new `markRanges`), `services/Reading.qml` (`tones`), `services/Doc.qml` (`adopt`), `components/MarkdownView.qml` (`changes`)
- Test: `test/tst_blocks.qml`, `test/tst_inline.qml`

**Interfaces:**
- Produces: `Blocks.index(blocks) -> { headings, anchors, pieces }`. Runs may carry `ins: true` or `del: true`. `Inline.markRanges(runs) -> [{ a, b, kind }]` with `a`, `b` document positions (chip padding counted, as `chipRanges`). `Reading.tones.ins`, `Reading.tones.del` (hex strings). `Doc.adopt({ blocks, headings, anchors, pieces, lineCount, source })`. `MarkdownView.changes` (object with those fields, or null).

- [ ] **Step 1: Failing tests**

Append to `test/tst_blocks.qml`:

```qml
  function test_index_matches_build() {
    var d = Blocks.build("# A\n\nx\n\n## B\n\ny `c` z\n")
    var ix = Blocks.index(d.blocks)
    compare(ix.headings.length, 2)
    compare(ix.headings[1].slug, "b")
    compare(ix.anchors["b"], 2)
    compare(ix.pieces.length, d.pieces.length)
  }
```

Append to `test/tst_inline.qml`:

```qml
  function test_mark_ranges() {
    var rs = [{ t: "We propose a " }, { t: "twelve", del: true }, { t: "ten", ins: true }, { t: "-week `x` " }, { t: "plan", ins: true }]
    var m = Inline.markRanges(rs)
    compare(m.length, 3)
    compare(m[0], { a: 13, b: 19, kind: "del" })
    compare(m[1], { a: 19, b: 22, kind: "ins" })
    // "-week " (6) + chip "x" with two pad chars (3) + " " (1) = 10 after position 22
    compare(m[2], { a: 32, b: 36, kind: "ins" })
  }

  function test_del_run_is_faint() {
    var html = Inline.toHtml([{ t: "old", del: true }], Object.assign({}, tones, { del: "#444444" }))
    verify(html.indexOf("color:#444444") > 0)
  }
```

Run `tools/test`; expected: the three new tests fail (`index` and `markRanges` are not functions).

- [ ] **Step 2: `blocks.js`: `index`**

Replace the tail of `build` (from `var seen = {}, headings = []` to the return) with:

```js
  var ix = index(blocks)
  return { blocks: blocks, headings: ix.headings, lineCount: lineCount, anchors: ix.anchors, pieces: ix.pieces }
}

// Headings (with slugs stamped on the heading blocks), anchors and find
// pieces for a block list. build() uses it; a prepared document (a diff)
// calls it on its own blocks.
function index(blocks) {
  var seen = {}, headings = []
  for (var i = 0; i < blocks.length; i++) {
    var b = blocks[i]
    if (b.type !== "heading") continue
    var base = slugify(b.text)
    var n = seen[base] || 0
    seen[base] = n + 1
    b.slug = n ? base + "-" + n : base
    headings.push({ level: b.level, text: b.text, slug: b.slug, index: i, srcStart: b.srcStart })
  }
  return { headings: headings, anchors: anchors(blocks), pieces: stampPieces(blocks) }
}
```

- [ ] **Step 3: `inline.js`: `markRanges` and the `del` colour**

Add after `chipRanges`:

```js
// Document positions [a, b) of each run flagged ins or del, adjacent runs
// of one kind merged, chip padding counted as in chipRanges().
function markRanges(rs) {
  var out = [], at = 0
  for (var i = 0; i < (rs || []).length; i++) {
    var r = rs[i], len = r.t.length + (r.code ? 2 : 0)
    var kind = r.ins ? "ins" : r.del ? "del" : ""
    if (kind && !r.br) {
      var last = out[out.length - 1]
      if (last && last.kind === kind && last.b === at) last.b = at + len
      else out.push({ a: at, b: at + len, kind: kind })
    }
    at += len
  }
  return out
}
```

In `toHtml`, after the `r.s` line:

```js
    if (r.del) s = "<span style=\"color:" + (tones.del || tones.faint || tones.dim) + "\">" + s + "</span>"
```

- [ ] **Step 4: `Reading.qml` tones**

Inside `tones`, after `rawText`:

```qml
    ins: Theme.hex(Theme.flat(Theme.green, Theme.light ? 0.22 : 0.26)),
    del: Theme.hex(Theme.faint),
    delLine: Theme.hex(Theme.flat(Theme.red, 0.85)),
```

- [ ] **Step 5: `Doc.qml`: `adopt`**

Add after `parse`:

```qml
  // A document prepared elsewhere (a diff): blocks already built and
  // indexed. Same reload signals as a parse, so views keep their place.
  function adopt(doc) {
    var first = !loaded
    if (!first) aboutToReload()
    source = doc.source || ""
    headings = doc.headings || []
    anchorMap = doc.anchors || {}
    pieces = doc.pieces || []
    lineCount = doc.lineCount || 1
    blocks = doc.blocks || []
    loaded = true
    missing = false
    failed = false
    if (!first) { reloads++; reloaded() }
  }
```

- [ ] **Step 6: `MarkdownView.qml`: `changes`**

Add properties after `externalLinks`:

```qml
  // A prepared document: { blocks, headings, anchors, pieces, lineCount,
  // source }, as lib/diff in OmaChanges makes. Set, it replaces `path` and
  // `markdown`; a new object is a reload that keeps the reader's place.
  property var changes: null
  onChangesChanged: if (changes) mdDoc.adopt(changes)
  Component.onCompleted: if (changes) mdDoc.adopt(changes)
```

In the `Doc` element, make `path` and `text` inert while `changes` is set: `path: root.changes ? "" : root.path` and `text: root.changes ? "" : root.markdown`. In `onReloaded`, treat `changes` like `keepPlace`: `if (!root.path && !root.keepPlace && !root.changes) { root.freshDocument(); return }`. In `onAboutToReload`: `if (root.path || root.keepPlace || root.changes) mdView.captureAnchor()`. In `DocView`, `visible: (!!root.path || root.markdown !== "" || !!root.changes) && mdDoc.loaded`.

- [ ] **Step 7: Run the tests, commit**

`tools/test` expected: all pass.

```bash
git add -A && git commit -m "MarkdownView: a prepared document (changes) and ins/del run marks in the data"
```

### Task 3: OmaRead: paint the marks

**Files:**
- Modify: `components/RichText.qml`, `components/DocView.qml`, `components/blocks/ListBlock.qml`, `components/blocks/Heading.qml`
- Create: `components/blocks/Fold.qml`
- Modify: `components/Block.qml`, `components/MarkdownView.qml` (`unfoldRequested`, `ctx.unfold`)

**Interfaces:**
- Consumes: `Inline.markRanges`, `Reading.tones.ins/del/delLine`.
- Produces: a block with `change` in `added|removed|reworded` draws its gutter word; `added` also draws a wash. A `{ type: "fold", count, kinds, heading? }` block draws the fold row; clicking it calls `ctx.unfold(index)`, which emits `MarkdownView.unfoldRequested(index)`. List items with `change` draw a gutter word.

- [ ] **Step 1: `RichText.qml`: marks under and over the text**

Generalise the chip layout. Replace the `chipSpans`/`chips`/`layoutChips` section with one that lays out any span list into line pieces, then two Repeaters:

```qml
  readonly property var chipSpans: Inline.chipRanges(runs)
  readonly property var markSpans: Inline.markRanges(runs)
  property var chips: []
  property var marks: []
  readonly property real chipH: Math.round(Reading.tones.codeSize * 1.5)

  // Each [a, b) span as one rectangle per line it covers.
  function piecesOf(spans) {
    var out = []
    for (var i = 0; i < spans.length; i++) {
      var a = spans[i].a !== undefined ? spans[i].a : spans[i][0]
      var b = spans[i].b !== undefined ? spans[i].b : spans[i][1]
      var kind = spans[i].kind || ""
      var ra = positionToRectangle(a), rb = positionToRectangle(b)
      var from = a
      while (ra.y < rb.y - 1) {
        var k = from + 1
        while (k < b && positionToRectangle(k).y <= ra.y + 1) k++
        var rEnd = positionToRectangle(k - 1)
        var w = rEnd.x + (rEnd.x < ra.x ? 0 : size * 0.5) - ra.x
        out.push({ x: ra.x, y: ra.y, w: Math.max(4, w), kind: kind })
        from = k
        ra = positionToRectangle(k)
      }
      out.push({ x: ra.x, y: ra.y, w: Math.max(4, rb.x - ra.x), kind: kind })
    }
    return out
  }

  function layoutChips() { chips = chipSpans.length ? piecesOf(chipSpans) : [] }
  function layoutMarks() { marks = markSpans.length ? piecesOf(markSpans) : [] }
  function relayout() { layoutChips(); layoutMarks() }

  onChipSpansChanged: Qt.callLater(layoutChips)
  onMarkSpansChanged: Qt.callLater(layoutMarks)
  onWidthChanged: Qt.callLater(relayout)
  onTextChanged: Qt.callLater(relayout)
```

Keep the chip Repeater as it is. Add:

```qml
  // Inserted text sits on a wash behind the line; removed text takes a
  // strike in the theme's red over it (rich text cannot colour a strike
  // apart from its text).
  Repeater {
    model: root.marks
    Rectangle {
      required property var modelData
      readonly property bool ins: modelData.kind === "ins"
      z: ins ? -1 : 1
      x: Math.round(modelData.x) - (ins ? 2 : 0)
      y: ins ? Math.round(modelData.y + root.chipOffset - (root.lineHeightPx - root.chipH) * 0.1) : Math.round(modelData.y + root.strikeOffset)
      width: Math.round(modelData.w) + (ins ? 4 : 0)
      height: ins ? Math.round(root.size * 1.25) : Math.max(1, Math.round(root.size / 11))
      radius: ins ? 3 : 0
      color: ins ? Reading.tones.ins : Reading.tones.delLine
    }
  }
  readonly property real strikeOffset: Math.round(chipMetrics.ascent - chipMetrics.xHeight * 0.55)
```

Check `chipOffset` still exists below and `chipMetrics` is declared before use (it is a sibling; QML binds lazily).

- [ ] **Step 2: `DocView.qml`: gutter word and wash**

In the delegate, before `Block`:

```qml
    readonly property string change: modelData.change && modelData.change !== "same" && modelData.type !== "list" ? modelData.change : ""

    // A whole added block sits on a soft wash; removed and reworded blocks
    // say so in the margin.
    Rectangle {
      visible: row.change === "added"
      x: root.gutter - Style.space(12)
      y: row.gap - Style.space(6)
      width: root.column + Style.space(24)
      height: block.height + Style.space(12)
      radius: Math.max(6, Style.cornerRadius)
      color: Theme.flat(Theme.green, Theme.light ? 0.08 : 0.1)
    }
    Text {
      visible: row.change !== ""
      x: root.gutter - width - Math.round(Reading.body * 0.9)
      y: row.gap + Math.round(Reading.body * 0.35)
      text: row.change
      textFormat: Text.PlainText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.4
      color: row.change === "added" ? Theme.green : row.change === "removed" ? Theme.red : Theme.faint
      opacity: row.change === "removed" ? 0.85 : 1
    }
```

`Theme.flat` returns a color; check its signature in `services/Theme.qml` (`flat(c, a)` flattens `c` at alpha `a` onto the page).

- [ ] **Step 3: `ListBlock.qml`: item gutter word**

Inside the item `Item`, after the marker:

```qml
      Text {
        visible: !!item.modelData.change && item.modelData.change !== "same"
        x: marker.x - width - Math.round(root.textSize * 0.6)
        y: Math.round(root.xCentre - height / 2)
        text: item.modelData.change || ""
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 0.4
        color: item.modelData.change === "added" ? Theme.green : item.modelData.change === "removed" ? Theme.red : Theme.faint
      }
```

- [ ] **Step 4: `Fold.qml`**

```qml
import QtQuick
import qs.Commons
import qs.services
import qs.components

// A run of unchanged blocks folded to one hairline row ("3 paragraphs
// unchanged"), or an unchanged section folded to its dimmed heading.
// Clicking asks the view to unfold it.
Item {
  id: root
  required property var block
  property var ctx: null
  property var look: ({})
  readonly property bool section: !!block.heading
  implicitHeight: section ? Math.round(Reading.size(block.heading.level <= 2 ? 2 : 1) * 1.5) : Math.round(Reading.body * 1.6)

  Row {
    visible: root.section
    anchors.verticalCenter: parent.verticalCenter
    spacing: Math.round(Reading.body * 0.7)
    Text {
      text: root.section ? root.block.heading.text : ""
      textFormat: Text.PlainText
      font.family: Reading.heading
      font.styleName: Reading.headingStyle
      font.pixelSize: root.section ? Reading.size([0, 3, 2, 1, 0.5, 0, 0][root.block.heading.level]) : Reading.body
      color: Theme.dim
      anchors.baseline: parent.baseline
    }
    Text {
      text: "unchanged"
      textFormat: Text.PlainText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Theme.faint
      anchors.baseline: parent.baseline
    }
  }

  Row {
    visible: !root.section
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    spacing: Math.round(Reading.body * 0.8)
    Rectangle { width: (parent.width - label.width - parent.spacing * 2) / 2; height: 1; color: Theme.hairlineSoft; anchors.verticalCenter: parent.verticalCenter }
    Text {
      id: label
      text: root.block.count + (root.block.kinds === "paragraph" ? (root.block.count === 1 ? " paragraph" : " paragraphs") : (root.block.count === 1 ? " block" : " blocks")) + " unchanged"
      textFormat: Text.PlainText
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Theme.faint
      anchors.verticalCenter: parent.verticalCenter
    }
    Rectangle { width: (parent.width - label.width - parent.spacing * 2) / 2; height: 1; color: Theme.hairlineSoft; anchors.verticalCenter: parent.verticalCenter }
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  Rectangle { anchors.fill: parent; z: -1; radius: 4; color: hover.hovered ? Theme.hover : "transparent" }
  TapHandler { onTapped: if (root.ctx && root.ctx.unfold) root.ctx.unfold(root.block.index) }
}
```

Register in `Block.qml`: `fold: "blocks/Fold.qml"`.

In `MarkdownView.qml`: `signal unfoldRequested(int index)` and in `mdCtx`: `function unfold(index) { root.unfoldRequested(index) }`. In `Reading.gapBefore`, treat `fold` like a paragraph (no change needed: it falls to the default 0.9 em), and add `fold: 1` nowhere.

- [ ] **Step 5: Check visually**

Write `/tmp/omachanges-marks.qml` under the scratchpad that loads `MarkdownView` with a hand-made `changes` object (two paragraphs, one with ins/del runs, one `added`, one `removed`, a fold row) and run it with `tools/screenshot`-style offscreen grab, or simply run `tools/check-live` and look. Confirm: wash behind inserted words, red strike over removed, gutter words, fold row. Fix sizes until they match the brainstorm mock (`.superpowers/brainstorm/*/content/reading-views-v2.html` in the OmaChanges repo).

- [ ] **Step 6: Run tests, commit**

```bash
tools/test
git add -A && git commit -m "Change marks: ins wash, del strike, gutter words, added wash and the fold row"
```

### Task 4: OmaRead: push and move the submodule pointer

- [ ] **Step 1: Push `main`** (the submodule URL is GitHub, so a public clone must find the commit)

```bash
cd ~/projects/omaread && git push origin main
```

- [ ] **Step 2: Move the submodule**

```bash
cd ~/projects/omachanges/vendor/omaread && git fetch local && git checkout "$(git -C ~/projects/omaread rev-parse HEAD)"
cd ~/projects/omachanges && git add vendor/omaread && git commit -m "Vendor OmaRead with change marks"
```

### Task 5: Engine: words

**Files:**
- Create: `lib/diff/words.js`, `test/tst_words.qml`

**Interfaces:**
- Produces: `Words.tokenize(text) -> [{ t, key }]` (a token is a word, a punctuation mark or a run of whitespace; `key` is the comparison form: whitespace tokens all share key `" "`). `Words.diff(a, b) -> [{ kind: "eq"|"del"|"ins", a0, a1, b0, b1 }]` over token arrays by `key` (Myers). `Words.segments(aText, bText) -> [{ kind, text }]` with `eq` and `ins` text from `b`, `del` text from `a`, adjacent same-kind merged, whitespace-only differences folded into `eq`. `Words.similarity(aText, bText) -> 0..1` Dice over lower-cased word tokens.

- [ ] **Step 1: Failing tests**

```qml
import QtQuick
import QtTest
import "../lib/diff/words.js" as Words

TestCase {
  name: "Words"

  function test_tokenize() {
    var t = Words.tokenize("We propose, a ten-week plan.")
    compare(t.map(function(x) { return x.t }), ["We", " ", "propose", ",", " ", "a", " ", "ten", "-", "week", " ", "plan", "."])
  }

  function test_segments_reword() {
    var s = Words.segments("a twelve-week plan", "a ten-week plan")
    compare(s, [{ kind: "eq", text: "a " }, { kind: "del", text: "twelve" }, { kind: "ins", text: "ten" }, { kind: "eq", text: "-week plan" }])
  }

  function test_whitespace_is_not_a_change() {
    var s = Words.segments("one two\nthree", "one  two three")
    compare(s.length, 1)
    compare(s[0].kind, "eq")
    compare(s[0].text, "one  two three")
  }

  function test_insert_and_delete_at_ends() {
    compare(Words.segments("b c", "a b c"), [{ kind: "ins", text: "a " }, { kind: "eq", text: "b c" }])
    compare(Words.segments("a b c", "a b"), [{ kind: "eq", text: "a b" }, { kind: "del", text: " c" }])
  }

  function test_similarity() {
    fuzzyCompare(Words.similarity("the cat sat", "the cat sat"), 1, 0.001)
    verify(Words.similarity("the cat sat on the mat", "the cat sat on a mat") > 0.7)
    verify(Words.similarity("alpha beta", "gamma delta") < 0.01)
    compare(Words.similarity("", ""), 1)
  }
}
```

Run `tools/test -functions Words::test_tokenize`; expected: fails to load `words.js`.

- [ ] **Step 2: Implement**

```js
.pragma library

// Word-level differences between two texts.
//
// tokenize(text)            -> [{ t, key }]
// diff(a, b)                -> [{ kind, a0, a1, b0, b1 }]  (Myers, by key)
// segments(aText, bText)    -> [{ kind: eq|del|ins, text }]
// similarity(aText, bText)  -> 0..1 (Dice over words)

var WORD = /[\p{L}\p{N}_'’]+|\s+|[^\s\p{L}\p{N}_'’]/gu

function tokenize(text) {
  var out = [], m
  WORD.lastIndex = 0
  var s = String(text || "")
  while ((m = WORD.exec(s)) !== null) {
    var t = m[0]
    out.push({ t: t, key: /^\s+$/.test(t) ? " " : t })
  }
  return out
}

// Myers' O(ND) over keys; returns edit script as eq/del/ins blocks.
function diff(a, b) {
  var n = a.length, m = b.length, max = n + m
  var v = {}, trace = []
  v[1] = 0
  var d, k, x, y
  outer:
  for (d = 0; d <= max; d++) {
    var snapshot = {}
    for (k = -d; k <= d; k += 2) {
      if (k === -d || (k !== d && (v[k - 1] || 0) < (v[k + 1] || 0))) x = v[k + 1] || 0
      else x = (v[k - 1] || 0) + 1
      y = x - k
      while (x < n && y < m && a[x].key === b[y].key) { x++; y++ }
      v[k] = x
      snapshot[k] = x
      if (x >= n && y >= m) { trace.push(snapshot); break outer }
    }
    trace.push(snapshot)
  }
  // Walk back.
  var ops = []
  x = n; y = m
  for (d = trace.length - 1; d > 0; d--) {
    var vv = trace[d - 1]
    k = x - y
    var prevK = (k === -d || (k !== d && (vv[k - 1] || 0) < (vv[k + 1] || 0))) ? k + 1 : k - 1
    var prevX = vv[prevK] || 0, prevY = prevX - prevK
    while (x > prevX && y > prevY) { ops.push({ kind: "eq", a0: x - 1, a1: x, b0: y - 1, b1: y }); x--; y-- }
    if (x === prevX) ops.push({ kind: "ins", a0: x, a1: x, b0: y - 1, b1: y })
    else ops.push({ kind: "del", a0: x - 1, a1: x, b0: y, b1: y })
    x = prevX; y = prevY
  }
  while (x > 0 && y > 0) { ops.push({ kind: "eq", a0: x - 1, a1: x, b0: y - 1, b1: y }); x--; y-- }
  ops.reverse()
  return merge(ops)
}

function merge(ops) {
  var out = []
  for (var i = 0; i < ops.length; i++) {
    var o = ops[i], last = out[out.length - 1]
    if (last && last.kind === o.kind && last.a1 === o.a0 && last.b1 === o.b0) { last.a1 = o.a1; last.b1 = o.b1 }
    else out.push({ kind: o.kind, a0: o.a0, a1: o.a1, b0: o.b0, b1: o.b1 })
  }
  return out
}

function join(tokens, from, to) {
  var s = ""
  for (var i = from; i < to; i++) s += tokens[i].t
  return s
}

function onlySpace(tokens, from, to) {
  for (var i = from; i < to; i++) if (tokens[i].key !== " ") return false
  return true
}

function segments(aText, bText) {
  var a = tokenize(aText), b = tokenize(bText)
  var ops = diff(a, b), out = []
  function push(kind, text) {
    if (!text) return
    var last = out[out.length - 1]
    if (last && last.kind === kind) last.text += text
    else out.push({ kind: kind, text: text })
  }
  for (var i = 0; i < ops.length; i++) {
    var o = ops[i]
    if (o.kind === "eq") push("eq", join(b, o.b0, o.b1))
    else if (o.kind === "del") {
      // Whitespace that only moved reads as the new side's spacing.
      if (onlySpace(a, o.a0, o.a1)) continue
      push("del", join(a, o.a0, o.a1))
    } else {
      if (onlySpace(b, o.b0, o.b1)) push("eq", join(b, o.b0, o.b1))
      else push("ins", join(b, o.b0, o.b1))
    }
  }
  // A del directly followed by ins (or the reverse) is one replacement;
  // order them del then ins so the old reads before the new.
  for (var j = 0; j + 1 < out.length; j++) {
    if (out[j].kind === "ins" && out[j + 1].kind === "del") { var t = out[j]; out[j] = out[j + 1]; out[j + 1] = t }
  }
  return out
}

function wordBag(text) {
  var bag = {}, n = 0
  tokenize(text).forEach(function(tok) {
    if (tok.key === " " || !/[\p{L}\p{N}]/u.test(tok.t)) return
    var w = tok.t.toLowerCase()
    bag[w] = (bag[w] || 0) + 1
    n++
  })
  return { bag: bag, n: n }
}

function similarity(aText, bText) {
  var a = wordBag(aText), b = wordBag(bText)
  if (a.n === 0 && b.n === 0) return 1
  if (a.n === 0 || b.n === 0) return 0
  var shared = 0
  for (var w in a.bag) if (b.bag[w]) shared += Math.min(a.bag[w], b.bag[w])
  return 2 * shared / (a.n + b.n)
}
```

Note on the `segments` whitespace rule: an `eq` run of tokens is joined from `b`, so when the two sides differ only in whitespace the `del` of a space is dropped and the `ins` of a space becomes `eq`. The test `test_whitespace_is_not_a_change` relies on the Myers script pairing `two` with `two` across the differing spaces.

- [ ] **Step 3: Run, fix, commit**

`tools/test -functions 'Words::*'`; expected: all pass. If `test_whitespace_is_not_a_change` yields two `eq` segments, the merge in `push` handles it; if it yields a `del`, the whitespace key is not `" "` for `\n` (check the regex).

```bash
git add -A && git commit -m "Engine: tokens, Myers diff, segments and word similarity"
```

### Task 6: Engine: segments onto runs

**Files:**
- Create: `lib/diff/runs.js`, `test/tst_runs.qml`

**Interfaces:**
- Consumes: `Words.segments`, `Inline.plain`.
- Produces: `Runs.slice(runs, from, to) -> runs` copying the runs covering plain-text offsets `[from, to)`, split at the edges. `Runs.markRuns(fromRuns, toRuns) -> { runs, changed }` where `runs` is the merged sequence (del runs from `fromRuns`, eq and ins runs from `toRuns`) and `changed` is false when no `del` or `ins` run was made. `Runs.markAll(runs, kind) -> runs` copies with every run flagged `kind`.

- [ ] **Step 1: Failing tests**

```qml
import QtQuick
import QtTest
import "../lib/blocks.js" as Blocks
import "../lib/inline.js" as Inline
import "../lib/diff/runs.js" as Runs

TestCase {
  name: "Runs"
  function runsOf(src) { return Blocks.build(src).blocks[0].runs }

  function test_slice_splits_runs() {
    var rs = runsOf("plain **bold** end")
    var s = Runs.slice(rs, 3, 9)        // "in bo" + "l"? plain is "plain bold end"
    compare(Inline.plain(s), "in bol")
    compare(s.length, 2)
    verify(!s[0].b && s[1].b)
  }

  function test_mark_reword() {
    var m = Runs.markRuns(runsOf("a twelve-week plan"), runsOf("a *ten*-week plan"))
    verify(m.changed)
    var del = m.runs.filter(function(r) { return r.del }), ins = m.runs.filter(function(r) { return r.ins })
    compare(Inline.plain(del), "twelve")
    compare(Inline.plain(ins), "ten")
    verify(ins[0].i)
    compare(Inline.plain(m.runs), "a twelveten-week plan")
  }

  function test_unchanged_is_not_changed() {
    var m = Runs.markRuns(runsOf("same text\nwrapped"), runsOf("same text wrapped"))
    verify(!m.changed)
    compare(Inline.plain(m.runs), "same text wrapped")
  }

  function test_mark_all() {
    var rs = Runs.markAll(runsOf("gone **now**"), "del")
    verify(rs.every(function(r) { return r.del }))
    verify(rs[1].b)
  }
}
```

The expected plain string in `test_slice_splits_runs` must match what `slice(rs, 3, 9)` of `"plain bold end"` gives: `"in bol"`. Fix the comment, keep the assertion.

- [ ] **Step 2: Implement**

```js
.pragma library
.import "words.js" as Words
.import "../inline.js" as Inline

// Word differences painted onto OmaRead runs.
//
// slice(runs, from, to)        -> runs for plain offsets [from, to)
// markRuns(fromRuns, toRuns)   -> { runs, changed }
// markAll(runs, kind)          -> runs flagged ins or del

function copy(r) {
  var o = {}
  for (var k in r) o[k] = r[k]
  return o
}

function slice(runs, from, to) {
  var out = [], at = 0
  for (var i = 0; i < (runs || []).length; i++) {
    var r = runs[i], len = r.t.length, end = at + len
    if (end > from && at < to) {
      var c = copy(r)
      c.t = r.t.slice(Math.max(0, from - at), Math.min(len, to - at))
      if (c.t.length) out.push(c)
    }
    at = end
    if (at >= to) break
  }
  return out
}

function markAll(runs, kind) {
  return (runs || []).map(function(r) { var c = copy(r); c[kind] = true; return c })
}

function markRuns(fromRuns, toRuns) {
  var a = Inline.plain(fromRuns), b = Inline.plain(toRuns)
  var segs = Words.segments(a, b)
  var out = [], posA = 0, posB = 0, changed = false
  for (var i = 0; i < segs.length; i++) {
    var s = segs[i], n = s.text.length
    if (s.kind === "eq") {
      // Advance the from side past the same words, whatever its spacing.
      posA = advance(a, posA, s.text)
      out = out.concat(slice(toRuns, posB, posB + n))
      posB += n
    } else if (s.kind === "del") {
      // The deleted text may start after whitespace the new side dropped.
      var start = a.indexOf(s.text, posA)
      if (start < 0) start = posA
      out = out.concat(markAll(slice(fromRuns, start, start + n), "del"))
      posA = start + n
      changed = true
    } else {
      out = out.concat(markAll(slice(toRuns, posB, posB + n), "ins"))
      posB += n
      changed = true
    }
  }
  return { runs: out, changed: changed }
}

// Move `pos` through `text` past the words of `eqText`, which may be
// spaced differently; returns the new position.
function advance(text, pos, eqText) {
  var want = Words.tokenize(eqText).filter(function(t) { return t.key !== " " })
  var i = pos
  for (var w = 0; w < want.length; w++) {
    var at = text.indexOf(want[w].t, i)
    if (at < 0) return i
    i = at + want[w].t.length
  }
  return i
}
```

- [ ] **Step 3: Run, commit**

`tools/test -functions 'Runs::*'`. Expected: pass.

```bash
git add -A && git commit -m "Engine: word differences onto runs"
```

### Task 7: Engine: alignment

**Files:**
- Create: `lib/diff/align.js`, `test/tst_align.qml`

**Interfaces:**
- Produces: `Align.lcs(a, b, keyOf) -> [[i, j], …]` matched index pairs in order. `Align.pairBySimilarity(aIdx, bIdx, simOf, threshold) -> [[i, j], …]` non-crossing pairs from two index lists, best similarity first. `Align.plan(a, b, keyOf, simOf, threshold) -> { pairs: [[i, j, exact]], removed: [i…], added: [j…] }` combining both.

- [ ] **Step 1: Failing tests**

```qml
import QtQuick
import QtTest
import "../lib/diff/align.js" as Align

TestCase {
  name: "Align"
  function id(x) { return x }

  function test_lcs() {
    compare(Align.lcs(["a", "b", "c", "d"], ["a", "c", "x", "d"], id), [[0, 0], [2, 1], [3, 3]])
  }

  function test_pair_by_similarity_does_not_cross() {
    // a0 ~ b1 strongly, a1 ~ b0 weakly: only one pair survives.
    function sim(i, j) { return (i === 0 && j === 1) ? 0.9 : (i === 1 && j === 0) ? 0.6 : 0 }
    compare(Align.pairBySimilarity([0, 1], [0, 1], sim, 0.5), [[0, 1]])
  }

  function test_plan() {
    var a = ["Intro", "The twelve-week plan has three stages", "Same", "Gone"]
    var b = ["Intro", "The ten-week plan has three stages", "New", "Same"]
    function sim(i, j) { return a[i].split(" ").filter(function(w) { return b[j].split(" ").indexOf(w) >= 0 }).length / Math.max(a[i].split(" ").length, b[j].split(" ").length) }
    var p = Align.plan(a, b, id, sim, 0.5)
    compare(p.pairs, [[0, 0, true], [1, 1, false], [2, 3, true]])
    compare(p.removed, [3])
    compare(p.added, [2])
  }
}
```

- [ ] **Step 2: Implement**

```js
.pragma library

// Aligning two block sequences.
//
// lcs(a, b, keyOf)                                -> [[i, j]] exact matches in order
// pairBySimilarity(aIdx, bIdx, simOf, threshold)  -> [[i, j]] non-crossing pairs
// plan(a, b, keyOf, simOf, threshold)             -> { pairs: [[i, j, exact]], removed, added }

function lcs(a, b, keyOf) {
  var n = a.length, m = b.length
  var ka = a.map(keyOf), kb = b.map(keyOf)
  var L = []
  for (var i = 0; i <= n; i++) { L.push(new Array(m + 1)); for (var j = 0; j <= m; j++) L[i][j] = 0 }
  for (i = n - 1; i >= 0; i--) for (j = m - 1; j >= 0; j--)
    L[i][j] = ka[i] === kb[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1])
  var out = []
  i = 0; j = 0
  while (i < n && j < m) {
    if (ka[i] === kb[j]) { out.push([i, j]); i++; j++ }
    else if (L[i + 1][j] >= L[i][j + 1]) i++
    else j++
  }
  return out
}

function pairBySimilarity(aIdx, bIdx, simOf, threshold) {
  var cands = []
  for (var x = 0; x < aIdx.length; x++) for (var y = 0; y < bIdx.length; y++) {
    var s = simOf(aIdx[x], bIdx[y])
    if (s >= threshold) cands.push({ i: aIdx[x], j: bIdx[y], s: s })
  }
  cands.sort(function(p, q) { return q.s - p.s || p.i - q.i || p.j - q.j })
  var chosen = []
  for (var c = 0; c < cands.length; c++) {
    var k = cands[c], ok = true
    for (var d = 0; d < chosen.length; d++) {
      var e = chosen[d]
      if (e.i === k.i || e.j === k.j || (e.i < k.i) !== (e.j < k.j)) { ok = false; break }
    }
    if (ok) chosen.push(k)
  }
  chosen.sort(function(p, q) { return p.i - q.i })
  return chosen.map(function(k) { return [k.i, k.j] })
}

function plan(a, b, keyOf, simOf, threshold) {
  var exact = lcs(a, b, keyOf)
  var usedA = {}, usedB = {}
  exact.forEach(function(p) { usedA[p[0]] = true; usedB[p[1]] = true })
  var restA = [], restB = []
  for (var i = 0; i < a.length; i++) if (!usedA[i]) restA.push(i)
  for (var j = 0; j < b.length; j++) if (!usedB[j]) restB.push(j)
  // Similarity pairs may not cross exact ones either: pair within the
  // gaps between consecutive exact matches.
  var pairs = exact.map(function(p) { return [p[0], p[1], true] })
  var bounds = [[-1, -1]].concat(exact).concat([[a.length, b.length]])
  for (var g = 0; g + 1 < bounds.length; g++) {
    var ga = restA.filter(function(x) { return x > bounds[g][0] && x < bounds[g + 1][0] })
    var gb = restB.filter(function(y) { return y > bounds[g][1] && y < bounds[g + 1][1] })
    pairBySimilarity(ga, gb, simOf, threshold).forEach(function(p) { pairs.push([p[0], p[1], false]); usedA[p[0]] = true; usedB[p[1]] = true })
  }
  pairs.sort(function(p, q) { return p[0] - q[0] })
  var removed = [], added = []
  for (i = 0; i < a.length; i++) if (!usedA[i]) removed.push(i)
  for (j = 0; j < b.length; j++) if (!usedB[j]) added.push(j)
  return { pairs: pairs, removed: removed, added: added }
}
```

- [ ] **Step 3: Run, commit**

```bash
tools/test -functions 'Align::*'
git add -A && git commit -m "Engine: LCS alignment and non-crossing similarity pairing"
```

### Task 8: Engine: the comparison

**Files:**
- Create: `lib/diff/changes.js`, `test/tst_changes.qml`
- Create: `samples/proposal-before.md`, `samples/proposal-after.md` (the brainstorm's invented proposal, both versions, industry-neutral)

**Interfaces:**
- Consumes: `Blocks.build`, `Blocks.index`, `Inline.plain`, `Runs`, `Align`, `Words.similarity`.
- Produces: `Changes.compare(fromText, toText) -> { blocks, total, lineCount, source }` where every top-level block carries `change` (`same|added|removed|reworded`) and `changes` (its count: 1, or changed items for a list); list items carry `change`; headings carry `sectionChanges`. `Changes.document(result) -> { blocks, headings, anchors, pieces, lineCount, source }` ready for `MarkdownView.changes`. `Changes.changedIndices(blocks) -> [i…]` top-level indices with `change !== "same"`.

- [ ] **Step 1: Failing tests**

```qml
import QtQuick
import QtTest
import "../lib/inline.js" as Inline
import "../lib/diff/changes.js" as Changes

TestCase {
  name: "Changes"

  function test_identical_is_zero() {
    var r = Changes.compare("# A\n\nx y z\n", "# A\n\nx y z\n")
    compare(r.total, 0)
    verify(r.blocks.every(function(b) { return b.change === "same" }))
  }

  function test_rewrap_is_zero() {
    var r = Changes.compare("# A\n\nThe quick brown fox\njumps over the lazy dog.\n", "# A\n\nThe quick brown fox jumps\nover the lazy dog.\n")
    compare(r.total, 0)
  }

  function test_reworded_paragraph() {
    var r = Changes.compare("# A\n\nWe propose a twelve-week plan.\n", "# A\n\nWe propose a ten-week plan.\n")
    compare(r.total, 1)
    compare(r.blocks[1].change, "reworded")
    compare(Inline.plain(r.blocks[1].runs.filter(function(x) { return x.del })), "twelve")
    compare(Inline.plain(r.blocks[1].runs.filter(function(x) { return x.ins })), "ten")
  }

  function test_added_and_removed_paragraphs() {
    var r = Changes.compare("# A\n\nkeep\n\ngone away\n", "# A\n\nkeep\n\nbrand new\n")
    compare(r.total, 2)
    compare(r.blocks.map(function(b) { return b.change }), ["same", "same", "removed", "added"])
    verify(r.blocks[2].runs.every(function(x) { return x.del }))
  }

  function test_empty_from_is_all_added() {
    var r = Changes.compare("", "# A\n\nx\n")
    compare(r.blocks.map(function(b) { return b.change }), ["added", "added"])
  }

  function test_list_items() {
    var r = Changes.compare("- weeks 1 to 4\n- weeks 5 to 8\n- same\n", "- weeks 1 to 3\n- weeks 4 to 6\n- same\n")
    compare(r.total, 2)
    compare(r.blocks[0].change, "reworded")
    compare(r.blocks[0].changes, 2)
    compare(r.blocks[0].items.map(function(it) { return it.change }), ["reworded", "reworded", "same"])
  }

  function test_retitled_section_pairs() {
    var r = Changes.compare("## Our approach\n\nbody\n", "## The approach\n\nbody\n")
    compare(r.blocks.length, 2)
    compare(r.blocks[0].change, "reworded")
    compare(r.blocks[1].change, "same")
  }

  function test_table_cell() {
    var r = Changes.compare("| a | b |\n|---|---|\n| 1 | 2 |\n", "| a | b |\n|---|---|\n| 1 | 3 |\n")
    compare(r.total, 1)
    compare(r.blocks[0].change, "reworded")
    compare(Inline.plain(r.blocks[0].rows[0][1].filter(function(x) { return x.ins })), "3")
  }

  function test_code_becomes_diff() {
    var r = Changes.compare("```sh\na\nb\n```\n", "```sh\na\nc\n```\n")
    compare(r.blocks[0].type, "diff")
    compare(r.blocks[0].change, "reworded")
    compare(r.blocks[0].lines.map(function(l) { return l.kind }), ["ctx", "del", "add"])
  }

  function test_section_counts_and_document() {
    var r = Changes.compare("# T\n\n## A\n\nold\n\n### A1\n\nx\n\n## B\n\nz\n", "# T\n\n## A\n\nnew\n\n### A1\n\nx y\n\n## B\n\nz\n")
    var d = Changes.document(r)
    var byText = {}
    d.headings.forEach(function(h) { byText[h.text] = h })
    compare(r.blocks[byText.T.index].sectionChanges, 2)
    compare(r.blocks[byText.A.index].sectionChanges, 2)
    compare(r.blocks[byText.A1.index].sectionChanges, 1)
    compare(r.blocks[byText.B.index].sectionChanges, 0)
    compare(Changes.changedIndices(r.blocks).length, 2)
    verify(d.pieces.length > 0)
  }
}
```

- [ ] **Step 2: Implement**

```js
.pragma library
.import "../blocks.js" as Blocks
.import "../inline.js" as Inline
.import "words.js" as Words
.import "runs.js" as Runs
.import "align.js" as Align

// Two Markdown texts -> the new document's blocks with change marks.
//
// compare(fromText, toText) -> { blocks, total, lineCount, source }
// document(result)          -> what MarkdownView.changes takes
// changedIndices(blocks)    -> top-level indices that changed

var SECTION_SIM = 0.6, BLOCK_SIM = 0.5

function plainOf(b) {
  switch (b.type) {
  case "paragraph": case "heading": return Inline.plain(b.runs)
  case "code": case "diff": return b.text
  case "list": return b.items.map(function(it) { return it.blocks.map(plainOf).join("\n") }).join("\n")
  case "quote": case "alert": return b.blocks.map(plainOf).join("\n")
  case "table": return b.header.map(Inline.plain).join("|") + "\n" + b.rows.map(function(r) { return r.map(Inline.plain).join("|") }).join("\n")
  case "image": return b.src + " " + b.alt
  case "gallery": return b.items.map(function(i) { return i.src }).join(" ")
  case "html": return b.text
  case "frontmatter": return b.title + "\n" + b.fields.map(function(f) { return f.key + ": " + f.value + (f.items || []).join(",") }).join("\n")
  case "footnotes": return b.items.map(function(it) { return it.label + " " + it.blocks.map(plainOf).join("\n") }).join("\n")
  default: return ""
  }
}

function norm(s) { return String(s).replace(/\s+/g, " ").trim() }
function keyOf(b) { return b.type + "\u0001" + norm(plainOf(b)) }

function clone(b) {
  var o = {}
  for (var k in b) o[k] = b[k]
  return o
}

function mark(b, change) {
  var c = clone(b)
  c.change = change
  c.changes = change === "same" ? 0 : 1
  return c
}

// Every run in a block (and its children) flagged `kind`.
function flagAll(b, kind) {
  var c = clone(b)
  if (c.runs) c.runs = Runs.markAll(c.runs, kind)
  if (c.blocks) c.blocks = c.blocks.map(function(x) { return flagAll(x, kind) })
  if (c.items) c.items = c.items.map(function(it) {
    var i2 = clone(it)
    if (i2.blocks) i2.blocks = i2.blocks.map(function(x) { return flagAll(x, kind) })
    return i2
  })
  if (c.type === "table") {
    c.header = c.header.map(function(r) { return Runs.markAll(r, kind) })
    c.rows = c.rows.map(function(row) { return row.map(function(r) { return Runs.markAll(r, kind) }) })
  }
  if (c.type === "code" && kind === "del") return codeAsDiff(c, c.text.split("\n").map(function(l) { return { kind: "del", text: l } }))
  return c
}

function codeAsDiff(code, lines) {
  var added = 0, removed = 0
  lines.forEach(function(l) { if (l.kind === "add") added++; else if (l.kind === "del") removed++ })
  return { type: "diff", lang: code.lang || "", text: lines.map(function(l) { return l.text }).join("\n"),
           lines: lines.map(function(l) { return { kind: l.kind, sign: l.kind === "add" ? "+" : l.kind === "del" ? "−" : " ", text: l.text } }),
           added: added, removed: removed, srcStart: code.srcStart, srcEnd: code.srcEnd, lineCount: lines.length }
}

// ---- pairing two blocks of one type

function pairBlocks(a, b) {
  switch (b.type) {
  case "paragraph": case "heading": {
    var m = Runs.markRuns(a.runs, b.runs)
    var c = clone(b); c.runs = m.runs
    return finish(c, m.changed)
  }
  case "list": return pairLists(a, b)
  case "quote": case "alert": {
    var inner = mergeSequences(a.blocks, b.blocks)
    var q = clone(b); q.blocks = inner.blocks
    return finish(q, inner.total > 0, inner.total)
  }
  case "table": return pairTables(a, b)
  case "code": {
    if (a.text === b.text) return mark(b, "same")
    var ops = Words.diff(a.text.split("\n").map(function(l) { return { t: l, key: l } }), b.text.split("\n").map(function(l) { return { t: l, key: l } }))
    var lines = []
    var al = a.text.split("\n"), bl = b.text.split("\n")
    ops.forEach(function(o) {
      if (o.kind === "eq") for (var i = o.b0; i < o.b1; i++) lines.push({ kind: "ctx", text: bl[i] })
      else if (o.kind === "del") for (var j = o.a0; j < o.a1; j++) lines.push({ kind: "del", text: al[j] })
      else for (var k = o.b0; k < o.b1; k++) lines.push({ kind: "add", text: bl[k] })
    })
    var d = codeAsDiff(b, lines)
    return finish(d, true)
  }
  case "frontmatter": {
    var fm = clone(b)
    var byKey = {}
    a.fields.forEach(function(f) { byKey[f.key] = f })
    var changed = a.title !== b.title
    fm.fields = b.fields.map(function(f) {
      var old = byKey[f.key]
      var same = old && old.value === f.value && (old.items || []).join("\n") === (f.items || []).join("\n")
      if (!same) changed = true
      var g = clone(f); g.change = same ? "same" : old ? "reworded" : "added"
      return g
    })
    return finish(fm, changed)
  }
  case "footnotes": {
    var fn = clone(b)
    var items = pairItems(a.items, b.items, function(it) { return it.label })
    fn.items = items.items
    return finish(fn, items.total > 0, items.total)
  }
  default:
    return keyOf(a) === keyOf(b) ? mark(b, "same") : null
  }
}

function finish(block, changed, count) {
  block.change = changed ? "reworded" : "same"
  block.changes = changed ? (count || 1) : 0
  return block
}

function pairLists(a, b) {
  var items = pairItems(a.items, b.items, function(it) { return norm(it.blocks.map(plainOf).join("\n")) })
  var l = clone(b)
  l.items = items.items
  return finish(l, items.total > 0, items.total)
}

// Items (list items, footnotes) aligned exactly then by similarity; each
// pair's blocks merged recursively.
function pairItems(aItems, bItems, keyFn) {
  var simOf = function(i, j) { return Words.similarity(keyFn(aItems[i]), keyFn(bItems[j])) }
  var p = Align.plan(aItems, bItems, keyFn, simOf, BLOCK_SIM)
  var out = [], total = 0
  var pairByA = {}, pairByB = {}
  p.pairs.forEach(function(pr) { pairByA[pr[0]] = pr; pairByB[pr[1]] = pr })
  // Emit in to-order; removed items go where their from-neighbour matched.
  var removedBefore = {}   // b index -> [a items removed before it]
  var trailing = []
  var nextB = 0
  for (var i = 0; i < aItems.length; i++) {
    if (pairByA[i]) { nextB = pairByA[i][1] + 1; continue }
    var slot = nextB < bItems.length ? nextB : -1
    if (slot < 0) trailing.push(i)
    else (removedBefore[slot] = removedBefore[slot] || []).push(i)
  }
  function removedItem(it) {
    var r = clone(it)
    r.blocks = it.blocks.map(function(x) { return flagAll(x, "del") })
    r.change = "removed"
    return r
  }
  for (var j = 0; j < bItems.length; j++) {
    (removedBefore[j] || []).forEach(function(i) { out.push(removedItem(aItems[i])); total++ })
    var it = clone(bItems[j])
    var pr = pairByB[j]
    if (!pr) { it.change = "added"; total++ }
    else if (pr[2]) it.change = "same"
    else {
      var inner = mergeSequences(aItems[pr[0]].blocks, bItems[j].blocks)
      it.blocks = inner.blocks
      it.change = inner.total > 0 ? "reworded" : "same"
      if (inner.total > 0) total++
    }
    out.push(it)
  }
  trailing.forEach(function(i) { out.push(removedItem(aItems[i])); total++ })
  return { items: out, total: total }
}

function pairTables(a, b) {
  var t = clone(b)
  var changed = false
  t.header = b.header.map(function(cell, c) {
    var m = Runs.markRuns(a.header[c] || [], cell)
    if (m.changed) changed = true
    return m.runs
  })
  var keyFn = function(row) { return norm(Inline.plain(row[0] || [])) }
  var simOf = function(i, j) { return Words.similarity(a.rows[i].map(Inline.plain).join(" "), b.rows[j].map(Inline.plain).join(" ")) }
  var p = Align.plan(a.rows, b.rows, keyFn, simOf, BLOCK_SIM)
  var byB = {}
  p.pairs.forEach(function(pr) { byB[pr[1]] = pr[0] })
  var rows = []
  // Removed rows are kept, struck, before the row that follows them.
  var removedBefore = {}, trailing = []
  var nextB = 0
  for (var i = 0; i < a.rows.length; i++) {
    var pr = p.pairs.filter(function(x) { return x[0] === i })[0]
    if (pr) { nextB = pr[1] + 1; continue }
    if (nextB < b.rows.length) (removedBefore[nextB] = removedBefore[nextB] || []).push(i)
    else trailing.push(i)
  }
  function struck(row) { changed = true; return row.map(function(cell) { return Runs.markAll(cell, "del") }) }
  for (var j = 0; j < b.rows.length; j++) {
    (removedBefore[j] || []).forEach(function(i) { rows.push(struck(a.rows[i])) })
    var row = b.rows[j]
    if (byB[j] === undefined) { changed = true; rows.push(row.map(function(cell) { return Runs.markAll(cell, "ins") })); continue }
    var aRow = a.rows[byB[j]]
    rows.push(row.map(function(cell, c) {
      var m = Runs.markRuns(aRow[c] || [], cell)
      if (m.changed) changed = true
      return m.runs
    }))
  }
  trailing.forEach(function(i) { rows.push(struck(a.rows[i])) })
  t.rows = rows
  return finish(t, changed)
}

// ---- sequences of blocks (a section's body, a quote's children)

function mergeSequences(aBlocks, bBlocks) {
  var simOf = function(i, j) {
    if (aBlocks[i].type !== bBlocks[j].type) return 0
    if (aBlocks[i].type === "image" || aBlocks[i].type === "hr") return 0
    return Words.similarity(plainOf(aBlocks[i]), plainOf(bBlocks[j]))
  }
  var p = Align.plan(aBlocks, bBlocks, keyOf, simOf, BLOCK_SIM)
  var byB = {}
  p.pairs.forEach(function(pr) { byB[pr[1]] = pr })
  var removedBefore = {}, trailing = [], nextB = 0
  for (var i = 0; i < aBlocks.length; i++) {
    var pr = p.pairs.filter(function(x) { return x[0] === i })[0]
    if (pr) { nextB = pr[1] + 1; continue }
    if (nextB < bBlocks.length) (removedBefore[nextB] = removedBefore[nextB] || []).push(i)
    else trailing.push(i)
  }
  var out = [], total = 0
  function removed(b, anchor) {
    var r = flagAll(b, "del")
    r.change = "removed"; r.changes = 1
    if (anchor) { r.srcStart = anchor.srcStart; r.srcEnd = anchor.srcStart }
    out.push(r); total++
  }
  for (var j = 0; j < bBlocks.length; j++) {
    (removedBefore[j] || []).forEach(function(i) { removed(aBlocks[i], bBlocks[j]) })
    var pr2 = byB[j]
    var blk
    if (!pr2) { blk = mark(bBlocks[j], "added") }
    else if (pr2[2]) { blk = mark(bBlocks[j], "same") }
    else { blk = pairBlocks(aBlocks[pr2[0]], bBlocks[j]) || mark(bBlocks[j], "added") }
    total += blk.changes
    out.push(blk)
  }
  var last = bBlocks[bBlocks.length - 1]
  trailing.forEach(function(i) { removed(aBlocks[i], last ? { srcStart: last.srcEnd } : null) })
  return { blocks: out, total: total }
}

// ---- sections

function sections(blocks) {
  var out = [{ heading: null, blocks: [] }]
  blocks.forEach(function(b) {
    if (b.type === "heading") out.push({ heading: b, blocks: [] })
    else out[out.length - 1].blocks.push(b)
  })
  return out
}

function sectionKey(s) { return s.heading ? s.heading.level + "\u0001" + norm(s.heading.text) : "\u0000" }

function compare(fromText, toText) {
  var a = Blocks.build(fromText || ""), b = Blocks.build(toText || "")
  var sa = sections(a.blocks), sb = sections(b.blocks)
  var simOf = function(i, j) {
    if (!sa[i].heading || !sb[j].heading || sa[i].heading.level !== sb[j].heading.level) return 0
    return Words.similarity(sa[i].heading.text, sb[j].heading.text)
  }
  var p = Align.plan(sa, sb, sectionKey, simOf, SECTION_SIM)
  var byB = {}
  p.pairs.forEach(function(pr) { byB[pr[1]] = pr })
  var removedBefore = {}, trailing = [], nextB = 0
  for (var i = 0; i < sa.length; i++) {
    var pr = p.pairs.filter(function(x) { return x[0] === i })[0]
    if (pr) { nextB = pr[1] + 1; continue }
    if (nextB < sb.length) (removedBefore[nextB] = removedBefore[nextB] || []).push(i)
    else trailing.push(i)
  }
  var out = [], total = 0
  function emitRemovedSection(s, anchor) {
    var all = (s.heading ? [s.heading] : []).concat(s.blocks)
    all.forEach(function(blk) {
      var r = flagAll(blk, "del"); r.change = "removed"; r.changes = 1
      if (anchor) { r.srcStart = anchor; r.srcEnd = anchor }
      out.push(r); total++
    })
  }
  for (var j = 0; j < sb.length; j++) {
    var anchorLine = sb[j].heading ? sb[j].heading.srcStart : (sb[j].blocks[0] ? sb[j].blocks[0].srcStart : 0)
    ;(removedBefore[j] || []).forEach(function(i) { emitRemovedSection(sa[i], anchorLine) })
    var pr2 = byB[j]
    if (!pr2) {
      if (sb[j].heading) { out.push(mark(sb[j].heading, "added")); total++ }
      sb[j].blocks.forEach(function(blk) { out.push(mark(blk, "added")); total++ })
      continue
    }
    var from = sa[pr2[0]]
    if (sb[j].heading) {
      var h = pr2[2] ? mark(sb[j].heading, "same") : pairBlocks(from.heading, sb[j].heading)
      total += h.changes
      out.push(h)
    }
    var body = mergeSequences(from.blocks, sb[j].blocks)
    out = out.concat(body.blocks)
    total += body.total
  }
  trailing.forEach(function(i) { emitRemovedSection(sa[i], b.lineCount) })
  sectionCounts(out)
  return { blocks: out, total: total, lineCount: Math.max(1, b.lineCount), source: toText || "" }
}

// Each heading's count covers its body and every deeper heading until the
// next heading at its level or above.
function sectionCounts(blocks) {
  for (var i = 0; i < blocks.length; i++) {
    if (blocks[i].type !== "heading") continue
    var n = 0
    for (var j = i + 1; j < blocks.length; j++) {
      if (blocks[j].type === "heading" && blocks[j].level <= blocks[i].level) break
      n += blocks[j].changes || 0
    }
    blocks[i].sectionChanges = n + (blocks[i].changes || 0)
  }
}

function document(result) {
  var ix = Blocks.index(result.blocks)
  return { blocks: result.blocks, headings: ix.headings, anchors: ix.anchors, pieces: ix.pieces,
           lineCount: result.lineCount, source: result.source }
}

function changedIndices(blocks) {
  var out = []
  for (var i = 0; i < blocks.length; i++) if (blocks[i].change && blocks[i].change !== "same") out.push(i)
  return out
}
```

Note: `Blocks.index` mutates heading `slug`s and stamps `pid`s on the blocks it is given, which is what the view needs. `compare` clones every block it emits, so the parsed originals are not reused.

- [ ] **Step 3: Write the samples**

`samples/proposal-before.md` and `samples/proposal-after.md`: the invented proposal from the brainstorm (title, Situation, Approach with the three-stage paragraph, the steering-group paragraph, the stages list, Team, Commercials, Next steps). "Before" has twelve weeks, "the organisation", the optional fourth stage and weeks 1 to 4 / 5 to 8 / 9 to 12. "After" has ten weeks, "Harbourline", the training paragraph, and 1 to 3 / 4 to 6 / 7 to 10. Harbourline Mutual is an invented name.

Add a test that compares the two samples and checks `total` is at least 6 and the Approach heading's `sectionChanges` is at least 4 (read the files with `XMLHttpRequest` over `file://`, as OmaRead's tests do if any; otherwise inline the texts in the test).

- [ ] **Step 4: Run, fix, commit**

`tools/test -functions 'Changes::*'`. Expect iteration on `test_rewrap_is_zero` (depends on Task 5's whitespace rule) and `test_retitled_section_pairs` (section similarity: "Our approach" against "The approach" is Dice 2·1/(2+2) = 0.5, below 0.6; change the test headings to "Our approach to the work" and "The approach to the work", similarity 2·4/(5+5) = 0.8).

```bash
git add -A && git commit -m "Engine: compare two documents block by block, word by word"
```

### Task 9: Engine: the fold

**Files:**
- Create: `lib/diff/fold.js`, `test/tst_fold.qml`

**Interfaces:**
- Produces: `Fold.fold(blocks, open) -> blocks` where `open` is an object of top-level indices (into the unfolded list) the user has opened. Runs of consecutive `same` non-heading blocks become `{ type: "fold", count, kinds, index, srcStart, srcEnd, change: "same", changes: 0 }` where `index` is the unfolded index of the first folded block. A heading whose `sectionChanges` is 0 becomes `{ type: "fold", heading, count, index, … }` and its whole section (to the next heading at its level or above) is dropped. `Fold.unfoldedIndex(folded, i)` maps a folded index back.

- [ ] **Step 1: Failing tests**

```qml
import QtQuick
import QtTest
import "../lib/diff/changes.js" as Changes
import "../lib/diff/fold.js" as Fold

TestCase {
  name: "Fold"

  function test_folds_runs_and_sections() {
    var r = Changes.compare("# T\n\n## A\n\na\n\nb\n\nc old\n\nd\n\n## B\n\nx\n\ny\n", "# T\n\n## A\n\na\n\nb\n\nc new\n\nd\n\n## B\n\nx\n\ny\n")
    var f = Fold.fold(r.blocks, {})
    compare(f.map(function(b) { return b.type + (b.type === "fold" ? ":" + (b.heading ? "section" : b.count) : "") }),
            ["heading", "heading", "fold:2", "paragraph", "fold:1", "fold:section"])
    compare(f[2].index, 2)
    compare(f[2].kinds, "paragraph")
  }

  function test_open_keeps_a_run() {
    var r = Changes.compare("a\n\nb\n\nc old\n", "a\n\nb\n\nc new\n")
    var f = Fold.fold(r.blocks, { 0: true })
    compare(f.map(function(b) { return b.type }), ["paragraph", "paragraph", "paragraph"])
  }
}
```

- [ ] **Step 2: Implement**

```js
.pragma library

// Collapse the unchanged. fold(blocks, open) -> blocks with fold rows.

function fold(blocks, open) {
  open = open || {}
  var out = [], i = 0
  while (i < blocks.length) {
    var b = blocks[i]
    if (b.type === "heading" && (b.sectionChanges || 0) === 0 && !open[i]) {
      var j = i + 1
      while (j < blocks.length && !(blocks[j].type === "heading" && blocks[j].level <= b.level)) j++
      out.push({ type: "fold", heading: b, count: j - i - 1, index: i, srcStart: b.srcStart, srcEnd: b.srcEnd, change: "same", changes: 0 })
      i = j
      continue
    }
    if (b.type !== "heading" && b.change === "same" && !open[i]) {
      var k = i, kinds = b.type
      while (k < blocks.length && blocks[k].type !== "heading" && blocks[k].change === "same" && !open[k]) {
        if (blocks[k].type !== kinds) kinds = "block"
        k++
      }
      out.push({ type: "fold", count: k - i, kinds: kinds, index: i, srcStart: b.srcStart, srcEnd: blocks[k - 1].srcEnd, change: "same", changes: 0 })
      i = k
      continue
    }
    var c = {}
    for (var key in b) c[key] = b[key]
    c.index = i
    out.push(c)
    i++
  }
  return out
}

// The unfolded index of folded row `i`.
function unfoldedIndex(folded, i) { return folded[i] ? folded[i].index : -1 }
```

Opening a run: the window records every unfolded index of the run (`index` to `index + count - 1`) in `open`, and for a section fold every index from `index` to the section's end.

- [ ] **Step 3: Run, commit**

```bash
tools/test -functions 'Fold::*'
git add -A && git commit -m "Engine: fold the unchanged"
```

### Task 10: Ruby: history

**Files:**
- Create: `lib/omachanges/history.rb`, `test/ruby/test_helper.rb`, `test/ruby/fixture_repo.rb`, `test/ruby/history_test.rb`
- Modify: `lib/omachanges.rb` (require)

**Interfaces:**
- Produces: `OmaChanges::History.new(path)` with `#in_repo?`, `#root`, `#rel`, `#versions -> [Version]` newest first, `#text_at(sha) -> String|nil`, `#disk_text`, `#user_name`. `Version = Struct.new(:sha, :author, :email, :time, :subject, :body)` where `time` is a `Time` in local zone.

- [ ] **Step 1: The fixture repository and a failing test**

`test/ruby/test_helper.rb`:

```ruby
require "minitest/autorun"
require "tmpdir"
require "omachanges"
require_relative "fixture_repo"
```

`test/ruby/fixture_repo.rb` builds a repository with scripted commits from two authors on fixed dates:

```ruby
module FixtureRepo
  COMMITS = [
    ["Keith Rowell", "keith@example.com", "2026-10-07T18:20:00+10:00", "Start the proposal", "v1 start\n\nSituation one.\n"],
    ["Keith Rowell", "keith@example.com", "2026-10-08T08:31:00+10:00", "Situation from the call notes", "v2\n\nSituation two.\n"],
    ["Danny Malone", "danny@example.com", "2026-10-17T14:50:00+10:00", "First pass at the approach", "v3\n\nApproach one.\n"],
    ["Keith Rowell", "keith@example.com", "2026-10-20T11:08:00+10:00", "Team section", "v4\n\nTeam.\n"],
    ["Danny Malone", "danny@example.com", "2026-10-23T16:12:00+10:00", "Tighten the approach section\n\nTwelve weeks reads as long.", "v5\n\nApproach two.\n"],
    ["Keith Rowell", "keith@example.com", "2026-10-24T17:02:00+10:00", "Use the client's name", "v6\n\nApproach three.\n"],
  ]

  # Builds the repo in dir; returns the document path. Commit times are the
  # author dates above, so date specs resolve to known commits.
  def self.build(dir, file: "proposal.md")
    path = File.join(dir, file)
    run(dir, "git", "init", "-q", "-b", "main")
    run(dir, "git", "config", "user.name", "Keith Rowell")
    run(dir, "git", "config", "user.email", "keith@example.com")
    File.write(File.join(dir, "SENT.md"), "Sent to the client on 21 October 2026.\n")
    COMMITS.each do |name, email, date, msg, text|
      File.write(path, text)
      run(dir, "git", "add", ".")
      env = { "GIT_AUTHOR_NAME" => name, "GIT_AUTHOR_EMAIL" => email, "GIT_AUTHOR_DATE" => date,
              "GIT_COMMITTER_NAME" => name, "GIT_COMMITTER_EMAIL" => email, "GIT_COMMITTER_DATE" => date }
      run(dir, env, "git", "commit", "-q", "-m", msg)
    end
    path
  end

  def self.run(dir, *cmd)
    env = cmd.first.is_a?(Hash) ? cmd.shift : {}
    system(env, *cmd, chdir: dir, out: File::NULL, err: File::NULL) or raise "failed: #{cmd.join(' ')}"
  end
end
```

`test/ruby/history_test.rb`:

```ruby
require_relative "test_helper"

class HistoryTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @path = FixtureRepo.build(@dir)
    @h = OmaChanges::History.new(@path)
  end

  def teardown = FileUtils.rm_rf(@dir)

  def test_versions_newest_first
    v = @h.versions
    assert_equal 6, v.size
    assert_equal "Use the client's name", v.first.subject
    assert_equal "Danny Malone", v[1].author
    assert_equal "Twelve weeks reads as long.", v[1].body
    assert_equal Time.parse("2026-10-23T16:12:00+10:00"), v[1].time
  end

  def test_text_at
    assert_equal "v5\n\nApproach two.\n", @h.text_at(@h.versions[1].sha)
  end

  def test_outside_a_repo
    Dir.mktmpdir do |d|
      f = File.join(d, "x.md"); File.write(f, "x")
      refute OmaChanges::History.new(f).in_repo?
    end
  end
end
```

Run: `tools/test`; expected: NameError for `OmaChanges::History`.

- [ ] **Step 2: Implement**

```ruby
module OmaChanges
  Version = Struct.new(:sha, :author, :email, :time, :subject, :body)

  # One file's git history, read through the git command.
  class History
    SEP = "\x1f"
    REC = "\x1e"

    attr_reader :path

    def initialize(path)
      @path = File.expand_path(path)
      @root = git_out("rev-parse", "--show-toplevel", dir: File.dirname(@path))&.strip
      @root = nil if @root && @root.empty?
    end

    def in_repo? = !@root.nil?
    def root = @root
    def rel = @path.delete_prefix("#{@root}/")

    def versions
      return [] unless in_repo?
      @versions ||= begin
        fmt = "%H#{SEP}%an#{SEP}%ae#{SEP}%aI#{SEP}%s#{SEP}%b#{REC}"
        out = git_out("log", "--follow", "--format=#{fmt}", "--", rel) || ""
        out.split(REC).map(&:strip).reject(&:empty?).map do |rec|
          sha, an, ae, date, subject, body = rec.split(SEP, 6)
          Version.new(sha, an, ae, Time.parse(date).localtime, subject, (body || "").strip)
        end
      end
    end

    def text_at(sha)
      return nil unless in_repo?
      # --follow may have renamed the file; ask git where it was at that commit.
      out = git_out("show", "#{sha}:#{rel}")
      return out if out
      name = git_out("log", "--follow", "--format=", "--name-only", "-1", sha, "--", rel)
      name = name&.strip
      name && !name.empty? ? git_out("show", "#{sha}:#{name}") : nil
    end

    def disk_text = File.read(@path)

    def user_name = (git_out("config", "user.name") || "").strip

    private

    def git_out(*args, dir: @root || File.dirname(@path))
      out = IO.popen(["git", *args], chdir: dir, err: File::NULL, &:read)
      $?.success? ? out : nil
    rescue Errno::ENOENT
      nil
    end
  end
end
```

Add `require_relative "omachanges/history"` to `lib/omachanges.rb`.

- [ ] **Step 3: Run, commit**

```bash
tools/test
git add -A && git commit -m "History: a file's versions through git"
```

### Task 11: Ruby: the resolver

**Files:**
- Create: `lib/omachanges/resolver.rb`, `test/ruby/resolver_test.rb`

**Interfaces:**
- Consumes: `History`.
- Produces: `OmaChanges::Resolver.new(history, now: Time)` with `#resolve(spec, before: Version|nil) -> Version | :now` raising `OmaChanges::Unresolved` (message is the banner sentence) when nothing matches; `#default_from(to_text) -> Version|nil` (newest version whose text differs); `#sent_date -> Date|nil`; `#shortcuts -> [{ "label", "spec" }]`; `#display(version) -> { "who" (first name), "name", "when" ("Thu 23 Oct, 4:12 pm"), "long" ("Thursday 23 October 2026, 4:12 pm"), "iso", "subject", "body", "sha" }`.

- [ ] **Step 1: Failing tests**

```ruby
require_relative "test_helper"

class ResolverTest < Minitest::Test
  NOW = Time.parse("2026-10-25T10:00:00+10:00")

  def setup
    @dir = Dir.mktmpdir
    @path = FixtureRepo.build(@dir)
    @h = OmaChanges::History.new(@path)
    @r = OmaChanges::Resolver.new(@h, now: NOW)
  end

  def teardown = FileUtils.rm_rf(@dir)

  def subject_of(spec, **kw) = @r.resolve(spec, **kw).subject

  def test_person
    assert_equal "Tighten the approach section", subject_of("danny")
    assert_equal "Tighten the approach section", subject_of("Danny Malone")
    assert_equal "Use the client's name", subject_of("keith")
    assert_equal "Use the client's name", subject_of("me")
  end

  def test_days
    assert_equal "Use the client's name", subject_of("yesterday")       # end of 24 Oct
    assert_equal "Tighten the approach section", subject_of("thu")      # most recent Thursday before today, 23 Oct
    assert_equal "Team section", subject_of("a week ago")               # end of 18 Oct
    assert_equal "First pass at the approach", subject_of("17 oct")
    assert_equal "First pass at the approach", subject_of("2026-10-17")
    assert_equal "Situation from the call notes", subject_of("3 days ago", ) if false
  end

  def test_person_and_day
    assert_equal "First pass at the approach", subject_of("danny fri")   # Fri 17 Oct
    assert_equal "Team section", subject_of("keith 20 oct")
  end

  def test_sent_reads_sent_md
    assert_equal Date.new(2026, 10, 21), @r.sent_date
    assert_equal "Team section", subject_of("sent")
  end

  def test_before
    assert_equal "Team section", subject_of("before danny")
  end

  def test_now_and_refs
    assert_equal :now, @r.resolve("now")
    assert_equal "Team section", subject_of("HEAD~2")
    assert_equal "Team section", subject_of(@h.versions[2].sha[0, 8])
  end

  def test_before_bound
    danny = @r.resolve("danny")
    assert_equal "Team section", subject_of("keith", before: danny)
  end

  def test_unresolved_messages
    e = assert_raises(OmaChanges::Unresolved) { @r.resolve("salman") }
    assert_equal "Salman has no check-ins of this file.", e.message
    e = assert_raises(OmaChanges::Unresolved) { @r.resolve("3 oct") }
    assert_equal "The file did not exist yet on 3 October.", e.message
  end

  def test_default_from
    assert_equal "Tighten the approach section", @r.default_from("v6\n\nApproach three.\n").subject
    assert_equal "Use the client's name", @r.default_from("edited on disk").subject
  end

  def test_shortcuts_and_display
    labels = @r.shortcuts.map { _1["label"] }
    assert_equal ["Danny's last edit", "my last edit", "yesterday", "a week ago", "when it was sent"], labels
    d = @r.display(@r.resolve("danny"))
    assert_equal "Danny", d["who"]
    assert_equal "Thu 23 Oct, 4:12 pm", d["when"]
    assert_equal "Thursday 23 October 2026, 4:12 pm", d["long"]
  end
end
```

Remove the `if false` line in `test_days` (it is a leftover) before running.

- [ ] **Step 2: Implement**

```ruby
module OmaChanges
  class Unresolved < StandardError; end

  # Turns a spec ("danny", "yesterday", "before danny fri", "sent", a ref)
  # into a Version of the file, or :now.
  class Resolver
    DAYS = %w[sunday monday tuesday wednesday thursday friday saturday]
    MONTHS = %w[january february march april may june july august september october november december]

    def initialize(history, now: Time.now)
      @h = history
      @now = now
    end

    def resolve(spec, before: nil)
      s = spec.to_s.strip.downcase
      return :now if s.empty? || s == "now"
      if s.start_with?("before ")
        target = resolve(s.sub(/\Abefore\s+/, ""), before: before)
        target = @h.versions.first if target == :now
        list = versions_before(before)
        i = list.index { _1.sha == target&.sha }
        raise Unresolved, "There is nothing before #{display(target)['who']}, #{display(target)['when']}." if i.nil? || i + 1 >= list.size
        return list[i + 1]
      end
      return resolve_sent(before) if s == "sent"

      words = s.split(/\s+/)
      person, day_words = split_person(words)
      day = day_words.empty? ? nil : parse_day(day_words.join(" "))
      if person.nil? && day.nil?
        ref = resolve_ref(spec.strip)
        return ref if ref
        raise Unresolved, "#{spec.strip.capitalize} has no check-ins of this file." if words.size <= 2 && words.all? { _1 =~ /\A[[:alpha:]'\-]+\z/ }
        raise Unresolved, "\"#{spec.strip}\" is not a person, a day or a version."
      end
      list = versions_before(before)
      list = list.select { |v| person_matches?(v, person) } if person
      if person && list.empty?
        name = person == "me" ? "You have" : "#{person.capitalize} has"
        raise Unresolved, "#{name} no check-ins of this file."
      end
      if day
        cutoff = Time.new(day.year, day.month, day.day, 23, 59, 59, @now.utc_offset)
        list = list.select { |v| v.time <= cutoff }
        raise Unresolved, "The file did not exist yet on #{day.day} #{MONTHS[day.month - 1].capitalize}." if list.empty?
      end
      list.first
    end

    # The newest version whose text differs from `text` (the to side).
    def default_from(text)
      @h.versions.find { |v| @h.text_at(v.sha) != text }
    end

    def sent_date
      f = File.join(File.dirname(@h.path), "SENT.md")
      return nil unless File.file?(f)
      s = File.read(f)
      if (m = s.match(/(\d{4})-(\d{2})-(\d{2})/)) then return Date.new(m[1].to_i, m[2].to_i, m[3].to_i) end
      if (m = s.match(/(\d{1,2})\s+(#{MONTHS.join('|')})\w*\s+(\d{4})/i)) then return Date.new(m[3].to_i, MONTHS.index(m[2].downcase[0, 3].then { |x| MONTHS.find { _1.start_with?(x) } }) + 1, m[1].to_i) end
      nil
    end

    def shortcuts
      me = @h.user_name
      others = @h.versions.map(&:author).uniq.reject { _1 == me }
      out = others.map { |n| { "label" => "#{first_name(n)}'s last edit", "spec" => first_name(n).downcase } }
      out << { "label" => "my last edit", "spec" => "me" }
      out << { "label" => "yesterday", "spec" => "yesterday" }
      out << { "label" => "a week ago", "spec" => "a week ago" }
      out << { "label" => "when it was sent", "spec" => "sent" } if sent_date
      out
    end

    def display(v)
      return { "label" => "Now", "who" => "Now" } if v == :now
      { "who" => first_name(v.author), "name" => v.author, "sha" => v.sha,
        "when" => v.time.strftime("%a %-d %b, %-l:%M %P"), "long" => v.time.strftime("%A %-d %B %Y, %-l:%M %P"),
        "iso" => v.time.iso8601, "subject" => v.subject, "body" => v.body }
    end

    private

    def first_name(name) = name.to_s.split(/\s+/).first.to_s

    def versions_before(before)
      list = @h.versions
      return list if before.nil? || before == :now
      i = list.index { _1.sha == before.sha }
      i ? list.drop(i + 1) : list
    end

    def person_matches?(v, person)
      return v.author == @h.user_name if person == "me"
      v.author.downcase.split(/\s+/).first == person || v.author.downcase == person
    end

    # Leading words that are a name (or "me") against the file's authors.
    def split_person(words)
      return ["me", words.drop(1)] if words.first == "me"
      authors = @h.versions.map { _1.author.downcase }
      firsts = authors.map { _1.split(/\s+/).first }
      full = words.join(" ")
      authors.each { |a| return [a.split(/\s+/).first, words.drop(a.split(/\s+/).size)] if full.start_with?(a) }
      return [words.first, words.drop(1)] if firsts.include?(words.first)
      # An unknown name followed by nothing day-like is still a person.
      return [words.first, []] if words.size == 1 && parse_day(words.first).nil? && words.first =~ /\A[[:alpha:]'\-]+\z/ && !resolvable_ref?(words.first)
      [nil, words]
    end

    def resolvable_ref?(s) = !resolve_ref(s).nil?

    def today = Date.new(@now.year, @now.month, @now.day)

    def parse_day(s)
      s = s.strip
      return today if s == "today"
      return today - 1 if s == "yesterday"
      return today - 7 if s == "a week ago" || s == "last week" || s == "1 week ago"
      if (m = s.match(/\A(\d+)\s+(day|week)s?\s+ago\z/)) then return today - m[1].to_i * (m[2] == "week" ? 7 : 1) end
      if (m = s.match(/\A(\d{4})-(\d{2})-(\d{2})\z/)) then return Date.new(m[1].to_i, m[2].to_i, m[3].to_i) end
      if (i = DAYS.index { |d| d == s || d[0, 3] == s })
        back = (today.wday - i) % 7
        back = 7 if back.zero?
        return today - back
      end
      if (m = s.match(/\A(\d{1,2})\s+([[:alpha:]]+)(?:\s+(\d{4}))?\z/) || s.match(/\A([[:alpha:]]+)\s+(\d{1,2})(?:\s+(\d{4}))?\z/))
        day, mon = m[1] =~ /\d/ ? [m[1], m[2]] : [m[2], m[1]]
        mi = MONTHS.index { |x| x == mon || x[0, 3] == mon[0, 3] }
        return nil unless mi
        year = (m[3] || @now.year).to_i
        d = Date.new(year, mi + 1, day.to_i) rescue nil
        d = d.prev_year if d && m[3].nil? && d > today
        return d
      end
      nil
    end

    def resolve_ref(ref)
      return nil unless @h.in_repo? && ref =~ /\A[\w.~^@{}\/-]+\z/
      sha = IO.popen(["git", "rev-parse", "--verify", "-q", "#{ref}^{commit}"], chdir: @h.root, err: File::NULL, &:read)
      return nil unless $?.success?
      sha = sha.strip
      @h.versions.find { _1.sha == sha } || begin
        rec = IO.popen(["git", "show", "-s", "--format=%H\x1f%an\x1f%ae\x1f%aI\x1f%s\x1f%b", sha], chdir: @h.root, err: File::NULL, &:read)
        h, an, ae, date, subject, body = rec.split("\x1f", 6)
        Version.new(h, an, ae, Time.parse(date).localtime, subject, (body || "").strip)
      end
    end

    def resolve_sent(before)
      d = sent_date or raise Unresolved, "There is no sent date in this directory."
      cutoff = Time.new(d.year, d.month, d.day, 23, 59, 59, @now.utc_offset)
      versions_before(before).find { _1.time <= cutoff } or raise Unresolved, "The file did not exist yet when it was sent."
    end
  end
end
```

Add `require_relative "omachanges/resolver"` to `lib/omachanges.rb`.

- [ ] **Step 3: Run, fix, commit**

`tools/test`. Expected: pass; the `sent_date` month lookup is the likeliest bug to iterate on (rewrite it as a plain loop if the `then` chain reads wrong).

```bash
git add -A && git commit -m "Resolver: people, days, sent, before and refs to versions"
```

### Task 12: Ruby: jobs and the full CLI

**Files:**
- Create: `lib/omachanges/job.rb`, `test/ruby/cli_test.rb`
- Modify: `lib/omachanges/cli.rb`

**Interfaces:**
- Produces: `Job.build(history, resolver, from_spec:, to_spec:) -> Hash` with keys `path`, `inRepo`, `from`, `to`, `history`, `shortcuts`, `banner` (a sentence or `nil`). Each of `from`/`to` is `display(v)` plus `"text"` and `"label"` (`"Now"` or the first name). `history` is `versions.map { display }`. CLI: `omachanges FILE [--from S] [--to S]` writes the job and opens it; `--list` prints one line per version `"<who>\t<when>\t<subject>"`; `--resolve S` prints the JSON of `display(v)` plus `text`, exit 1 with the sentence on stderr when unresolved; `--json` with no flags prints the job instead of opening it.

- [ ] **Step 1: Failing test**

```ruby
require_relative "test_helper"
require "open3"

class CliTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def setup
    @dir = Dir.mktmpdir
    @path = FixtureRepo.build(@dir)
  end

  def teardown = FileUtils.rm_rf(@dir)

  def run_cli(*args)
    Open3.capture3({ "OMACHANGES_NOW" => "2026-10-25T10:00:00+10:00" }, File.join(ROOT, "bin/omachanges"), *args)
  end

  def test_list
    out, _, st = run_cli(@path, "--list")
    assert st.success?
    lines = out.lines
    assert_equal 6, lines.size
    assert_match(/\AKeith\tFri 24 Oct, 5:02 pm\tUse the client's name/, lines.first)
  end

  def test_resolve
    out, _, st = run_cli(@path, "--resolve", "danny")
    assert st.success?
    j = JSON.parse(out)
    assert_equal "Danny", j["who"]
    assert_equal "v5\n\nApproach two.\n", j["text"]
  end

  def test_resolve_unresolved
    _, err, st = run_cli(@path, "--resolve", "salman")
    assert_equal 1, st.exitstatus
    assert_equal "Salman has no check-ins of this file.\n", err
  end

  def test_job_json
    out, _, st = run_cli(@path, "--from", "danny", "--json")
    assert st.success?
    j = JSON.parse(out)
    assert_equal "Danny", j["from"]["label"]
    assert_equal "Now", j["to"]["label"]
    assert_equal File.read(@path), j["to"]["text"]
    assert_equal 6, j["history"].size
    assert_nil j["banner"]
    assert_equal "when it was sent", j["shortcuts"].last["label"]
  end

  def test_default_from_differs_from_now
    out, _, _ = run_cli(@path, "--json")
    j = JSON.parse(out)
    assert_equal "Danny", j["from"]["label"]     # HEAD equals disk, so the one before
  end

  def test_to_only
    out, _, _ = run_cli(@path, "--to", "danny fri", "--json")
    j = JSON.parse(out)
    assert_equal "Situation from the call notes", j["from"]["subject"]
    assert_equal "First pass at the approach", j["to"]["subject"]
  end

  def test_banner_when_unresolved
    out, _, st = run_cli(@path, "--from", "salman", "--json")
    assert st.success?
    j = JSON.parse(out)
    assert_equal "Salman has no check-ins of this file.", j["banner"]
    assert_equal j["to"]["text"], j["from"]["text"]
  end

  def test_outside_repo
    Dir.mktmpdir do |d|
      f = File.join(d, "x.md"); File.write(f, "x\n")
      out, _, _ = run_cli(f, "--json")
      j = JSON.parse(out)
      assert_equal false, j["inRepo"]
      assert_equal "This file is not in a git repository, so it has no earlier versions.", j["banner"]
    end
  end
end
```

- [ ] **Step 2: `job.rb`**

```ruby
module OmaChanges
  module Job
    module_function

    def build(history, resolver, from_spec: nil, to_spec: nil)
      path = history.path
      to_text = history.disk_text
      job = { "path" => path, "inRepo" => history.in_repo?, "history" => [], "shortcuts" => [], "banner" => nil }
      unless history.in_repo?
        side = { "label" => "Now", "who" => "Now", "text" => to_text }
        return job.merge("from" => side, "to" => side, "banner" => "This file is not in a git repository, so it has no earlier versions.")
      end
      job["history"] = history.versions.map { resolver.display(_1) }
      job["shortcuts"] = resolver.shortcuts
      begin
        to = to_spec ? resolver.resolve(to_spec) : :now
        from = if from_spec then resolver.resolve(from_spec, before: to == :now ? nil : to)
               elsif to == :now then resolver.default_from(to_text)
               else resolver.resolve("before #{to_spec}") end
      rescue Unresolved => e
        job["banner"] = e.message
        to = :now
        from = nil
      end
      job["to"] = side(history, resolver, to, to_text)
      job["from"] = from ? side(history, resolver, from, to_text) : job["to"]
      if from.nil? && job["banner"].nil?
        job["banner"] = "This is the only version of the file."
      elsif job["banner"].nil? && job["from"]["text"] == job["to"]["text"]
        job["banner"] = "No changes since #{job['from']['who']}, #{job['from']['when']}."
      end
      job
    end

    def side(history, resolver, v, now_text)
      return { "label" => "Now", "who" => "Now", "text" => now_text } if v == :now
      resolver.display(v).merge("label" => resolver.display(v)["who"], "text" => history.text_at(v.sha) || "")
    end
  end
end
```

- [ ] **Step 3: The CLI**

Rewrite `run` in `cli.rb`:

```ruby
    def run
      return help if @argv.include?("-h") || @argv.include?("--help")
      return version if @argv.include?("-V") || @argv.include?("--version")
      foreground = !@argv.delete("--foreground").nil?
      json = !@argv.delete("--json").nil?
      from = take_value("--from")
      to = take_value("--to")
      list = !@argv.delete("--list").nil?
      resolve = take_value("--resolve")
      file = @argv.shift or return help
      path = File.expand_path(file.sub(%r{\Afile://}, ""))
      return error("#{file}: no such file") unless File.file?(path)
      history = History.new(path)
      now = ENV["OMACHANGES_NOW"] ? Time.parse(ENV["OMACHANGES_NOW"]) : Time.now
      resolver = Resolver.new(history, now: now)
      return do_list(history, resolver) if list
      return do_resolve(history, resolver, resolve) if resolve
      job = Job.build(history, resolver, from_spec: from, to_spec: to)
      if json then puts JSON.generate(job); return 0 end
      open_job(write_job(job), foreground: foreground)
    end

    def take_value(flag)
      i = @argv.index(flag) or return nil
      @argv.delete_at(i)
      @argv.delete_at(i)
    end

    def do_list(history, resolver)
      return error("not in a git repository") unless history.in_repo?
      history.versions.each { |v| d = resolver.display(v); puts [d["who"], d["when"], d["subject"]].join("\t") }
      0
    end

    def do_resolve(history, resolver, spec)
      v = resolver.resolve(spec)
      puts JSON.generate(Job.side(history, resolver, v, history.disk_text))
      0
    rescue Unresolved => e
      warn e.message
      1
    end
```

Add `require_relative "omachanges/job"` to `lib/omachanges.rb`.

- [ ] **Step 4: Run, commit**

```bash
tools/test
git add -A && git commit -m "CLI: jobs, --list, --resolve and --json"
```

### Task 13: Window: the comparison, header and banners

**Files:**
- Create: `ui/app/Comparison.qml`, `ui/app/ChangesHeader.qml`
- Modify: `ui/app/ChangesWindow.qml`, `ui/shell.qml`, `ui/app/qmldir`

**Interfaces:**
- Consumes: `Changes.compare/document`, `MarkdownView.changes`, job JSON.
- Produces: `Comparison { job, fromText, toText, document, total, fromLabel, toLabel, banner }`, re-running when `fromText` or `toText` change. `ChangesHeader { fileName, folder, from (display hash), to, total, foldOn, outlineShown, findShown; signals togglePill(), toggleFold(), toggleOutline(), toggleFind(), showHelp() }`. Window IPC `state` includes `total`, `from`, `to`, `banner`, `fold`.

- [ ] **Step 1: `Comparison.qml`**

```qml
import QtQuick
import "../lib/diff/changes.js" as Changes

// The two texts and the engine's result, recomputed when either changes.
QtObject {
  id: root
  property var job: null
  property var from: job ? job.from : null
  property var to: job ? job.to : null
  property string toText: to ? to.text : ""
  property string fromText: from ? from.text : ""
  property var result: null
  property var document: null
  readonly property int total: result ? result.total : 0
  readonly property string banner: job && job.banner ? job.banner : ""
  property int compareMs: 0

  function run() {
    var t0 = Date.now()
    result = Changes.compare(fromText, toText)
    compareMs = Date.now() - t0
    document = Changes.document(result)
  }
  onFromTextChanged: run()
  onToTextChanged: run()
  Component.onCompleted: run()
}
```

- [ ] **Step 2: `ChangesHeader.qml`**

Copy OmaRead's `Header.qml` structure. Left: Glyph, bold file name, mono folder. Right (a Row): the pill, the count, and `ChipButton`s for find (``), fold (`󰽾`, active when fold on, tip "Fold the unchanged  F"), outline (``), help (``). The pill:

```qml
    Rectangle {
      id: pill
      anchors.verticalCenter: parent.verticalCenter
      implicitHeight: Style.space(24)
      implicitWidth: pillRow.implicitWidth + Style.space(20)
      radius: height / 2
      color: pillHover.hovered || root.pillOpen ? Theme.hover : "transparent"
      border.width: 1
      border.color: Theme.hairline
      Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: Style.space(6)
        Text { text: root.to ? root.to.label : ""; font.bold: true; color: Theme.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "compared with"; color: Theme.dim; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        AuthorDisc { who: root.from ? root.from.who : ""; name: root.from ? (root.from.name || "") : ""; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.from ? root.from.label : ""; font.bold: true; color: Theme.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.from && root.from.when ? root.from.when.split(",")[0] : ""; color: Theme.dim; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
      }
      HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.togglePill() }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.total === 0 ? "no changes" : root.total === 1 ? "1 change" : root.total + " changes"
      color: Theme.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.features: { "tnum": 1 }
    }
```

`ui/app/AuthorDisc.qml`: a 16 px circle with the first letter of `who`, filled with a colour picked by a stable hash of `name` from `[Theme.blue, Theme.green, Theme.yellow, Theme.magenta, Theme.cyan]`; for `who === "Now"` an outlined circle with no letter. Letter colour `Theme.bg`.

- [ ] **Step 3: Wire the window**

In `ChangesWindow.qml`: a `Comparison { id: cmp; job: win.job }`; `MarkdownView { changes: cmp.document; keepPlace: true }`; the header at the top with `anchors.topMargin: header.height` on the body; `Banner { visible: cmp.banner !== ""; text: cmp.banner }` under the header; the progress hairline as OmaRead; a `Toast`. Title `"OmaChanges: " + fileName`. Watching Now:

```qml
  FileView {
    id: disk
    path: win.job && win.job.to && win.job.to.label === "Now" ? win.path : ""
    watchChanges: true
    printErrors: false
    onFileChanged: diskDebounce.restart()
    onLoaded: if (win.job && win.job.to.label === "Now") cmp.toText = text()
  }
  Timer { id: diskDebounce; interval: 150; onTriggered: disk.reload() }
```

Keys (copy `handleKey` from OmaRead, keep scrolling, `/`, `?`, `q`, `Esc`, zoom, `Ctrl+\`; add):

```qml
    else if (t === "n") win.step(1)
    else if (t === "p") win.step(-1)
    else if (t === "f") win.foldOn = !win.foldOn
    else if (t === "v") win.listShown = !win.listShown
    else if (t === "o") win.outlineWanted = !win.outlineWanted
```

`step(dir)`: from `Changes.changedIndices(shownBlocks)` pick the first index above the view's `topIndex` (or below for `-1`), `view.scrollToIndex(i, true)`, then flash: an overlay `Rectangle` in the window, `color: Theme.flat(Theme.accent, 0.12)`, placed over `view.itemAtIndex(i)` mapped into the window after the glide (`Timer 260 ms`), fading out over 600 ms.

`debugState()` returns `{ title, path, loaded, blocks, total: cmp.total, from: cmp.from ? cmp.from.label : "", to: cmp.to ? cmp.to.label : "", banner: cmp.banner, fold: foldOn, compareMs: cmp.compareMs, topIndex: view.topIndex, list: listShown }`.

`sendKey(spec)` as OmaRead's.

- [ ] **Step 4: Check offscreen**

```bash
cd ~/projects/omachanges && samples/make-repo /tmp/omachanges-sample   # written in Task 16; for now use the fixture: ruby -I test/ruby -e 'require "fixture_repo"; puts FixtureRepo.build("/tmp/omachanges-sample")'
export OMACHANGES_INSTANCE=dev-$$ QT_QPA_PLATFORM=offscreen
bin/omachanges --foreground /tmp/omachanges-sample/proposal.md --from danny &
pid=$!; sleep 2.5
qs ipc --pid $pid call omachanges state -1
qs ipc --pid $pid call omachanges shot -1 /tmp/omachanges-a.png
sleep 1; kill $pid
```

Expected: `total` above zero, `from` `Danny`. Open the PNG and compare with the brainstorm mock.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Window: comparison, header with the version pill, banners, keys and the file watch"
```

### Task 14: Window: outline with counts and the fold

**Files:**
- Create: `ui/app/ChangeOutline.qml`
- Modify: `ui/app/ChangesWindow.qml`

**Interfaces:**
- Consumes: `doc.headings`, `blocks[i].sectionChanges`, `Fold.fold`, `MarkdownView.unfoldRequested`.
- Produces: `ChangeOutline { headings, blocks, current, dimUnchanged; signal jump(int) }`. Window properties `foldOn`, `open` (object of unfolded indices), `shownBlocks`.

- [ ] **Step 1: `ChangeOutline.qml`**

Copy OmaRead's `Outline.qml` and change the delegate: drop the accent bar `Rectangle` (shading only marks the current item), add at the right a mono count:

```qml
      Text {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        readonly property int n: root.blocks[entry.modelData.index] ? (root.blocks[entry.modelData.index].sectionChanges || 0) : 0
        visible: n > 0
        text: String(n)
        color: Theme.text
        font.family: Reading.mono
        font.pixelSize: Style.font.caption
        font.features: { "tnum": 1 }
      }
```

and `opacity: root.dimUnchanged && n === 0 ? 0.5 : 1` on the label.

- [ ] **Step 2: The fold in the window**

```qml
  property bool foldOn: false
  property var open: ({})
  readonly property var fullBlocks: cmp.result ? cmp.result.blocks : []
  readonly property var shownDocument: {
    if (!cmp.document) return null
    if (!foldOn) return cmp.document
    var folded = Fold.fold(fullBlocks, open)
    var ix = Blocks.index(folded)
    return { blocks: folded, headings: ix.headings, anchors: ix.anchors, pieces: ix.pieces, lineCount: cmp.document.lineCount, source: cmp.document.source }
  }
```

`MarkdownView { changes: win.shownDocument; onUnfoldRequested: i => win.unfold(i) }`.

```qml
  function unfold(i) {
    var row = md.doc.blocks[i]
    if (!row || row.type !== "fold") return
    var o = Object.assign({}, open)
    var from = row.index, to = from + Math.max(1, row.count) + (row.heading ? 1 : 0)
    for (var k = from; k < to; k++) o[k] = true
    open = o
  }
  onFoldOnChanged: open = ({})
```

Note `Blocks.index` stamps new `pid`s on the folded clones; since `Fold.fold` copies blocks shallowly, `runs` arrays are shared but pids are per block copy, which is what find needs.

Import in the window: `import "../lib/diff/fold.js" as Fold` and `import "../lib/blocks.js" as Blocks` (through the `ui/lib` symlink).

- [ ] **Step 3: Check offscreen** as in Task 13, pressing `f` through `qs ipc … key -1 f` and reading `state` for `fold: true` and a smaller `blocks`.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "Outline with change counts, and the fold"
```

### Task 15: Window: the version list

**Files:**
- Create: `ui/app/VersionList.qml`, `ui/app/VersionCard.qml`
- Modify: `ui/app/ChangesWindow.qml`

**Interfaces:**
- Consumes: `job.history`, `job.shortcuts`, `bin/omachanges FILE --resolve SPEC`.
- Produces: `VersionList { history, shortcuts, currentSha, picking ("from"|"to"); signals pick(string spec), pickTwo(), closeRequested() }`. Window `resolveSpec(spec, side)` runs the CLI and assigns `cmp.fromText`/`cmp.toText` plus the display hashes; the header reads them.

- [ ] **Step 1: `VersionList.qml`**

A `Rectangle` 600 px wide anchored under the pill (right-aligned to it), `Color.popups.background`, hairline border, radius `Style.cornerRadius`, shadowed by a second `Rectangle` behind at 0.35 black alpha offset 6 px (as `FindBar` does, or none if Quickshell lacks shadows). Content:

- Section label "COMPARE NOW WITH" (caption, letter-spaced, `Theme.ghost`).
- A `Flow` of chips from `shortcuts`: `ChipButton { label: modelData.label; onClicked: root.pick(modelData.spec) }`.
- Section label "HISTORY".
- A `ListView` (max height 7 rows, scrollable) over `history`: each row two lines. Line 1: `AuthorDisc`, who (`Theme.text`), when (`Theme.faint`), nothing at the right. Line 2: subject in `Theme.dim`, `elide: Text.ElideRight`, indented 26 px. Row shading `Theme.hover` on hover, `Util.alpha(Theme.accent, 0.1)` when `modelData.sha === currentSha`. `TapHandler` → `root.pick(modelData.sha)`. A `HoverHandler` starts a 400 ms `Timer`; when it fires, `root.hoverRow = index`.
- `VersionCard` shown for `hoverRow`, positioned under that row, with subject (bold, `Theme.text`), body (`Theme.dim`, `wrapMode: Text.Wrap`), and `name + ", " + long` in caption `Theme.faint`.
- Foot: a hairline, "Compare two past versions…" as a `ChipButton` label at the right → `root.pickTwo()`.

Keys: `Esc` closes (the window's `handleKey` checks `listShown` first).

- [ ] **Step 2: Resolving a pick**

In the window:

```qml
  Process {
    id: resolver
    property string side: "from"
    stdout: StdioCollector { onStreamFinished: win.applyResolved(resolver.side, text) }
    stderr: StdioCollector { onStreamFinished: if (text.trim()) toast.show(text.trim()) }
  }
  function resolveSpec(spec, side) {
    resolver.side = side
    resolver.command = [Qt.resolvedUrl("../../bin/omachanges").toString().replace("file://", ""), win.path, "--resolve", spec]
    resolver.running = true
  }
  function applyResolved(side, json) {
    if (!json.trim()) return
    var v = JSON.parse(json)
    var j = Object.assign({}, win.job)
    j[side] = v
    j.banner = (j.from.text === j.to.text) ? "No changes since " + j.from.who + ", " + j.from.when + "." : null
    win.job = j
  }
```

`Comparison` derives `from`/`to`/texts from `job`, so assigning `win.job` re-runs the engine and the header updates. `Comparison.job` change must not reset `toText` while the disk watch owns it: `toText: to && to.label === "Now" && disk.loaded ? disk.text() : (to ? to.text : "")` is simpler expressed as: the disk `FileView.onLoaded` writes `cmp.toText` only when `to.label === "Now"`, and `Comparison` rebinds `toText` from the job on `jobChanged`.

"Compare two past versions…": `picking = "to"`; the next pick resolves into `to`, then `picking = "from"` and the list stays open for one more pick. The pill then shows `to.label to.when compared with from…`.

- [ ] **Step 3: Check** offscreen: `key -1 v` then `state` shows `list: true`; call a new IPC `pick -1 danny` added to the shell (`function pick(n, spec)` → `win.resolveSpec(spec, "from")`) and confirm `from` changes.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "Version list from the pill, with hover cards and two-version picks"
```

### Task 16: Samples, tools, install, README

**Files:**
- Create: `samples/make-repo`, `tools/check`, `tools/shot`, `tools/vendor`, `ops/install`, `ops/omachanges.desktop`, `ops/omachanges.svg`, `README.md`, `CHANGELOG.md`, `docs/decisions/0001-git-behind-the-launcher.md`
- Modify: `ui/app/HelpSheet.qml` (create, from OmaRead's `ShortcutSheet` with the spec's key table)

- [ ] **Step 1: `samples/make-repo DIR`**

A Ruby script that builds a repository in DIR from the two sample proposals plus intermediate edits by "Danny Malone" and "Keith Rowell" with the dates and messages of the brainstorm mock (eight commits), and writes `SENT.md`. Reuses the approach of `test/ruby/fixture_repo.rb` but with the real sample texts; the before/after files are the third-from-last and last commits.

- [ ] **Step 2: `tools/check`**

Model on OmaWriter's `tools/check`: build the sample repo in a temp dir, start an offscreen instance with `--foreground … --from danny &`, wait for `count` ≥ 1, then `expect`:

- `state` has `total` ≥ 6 and `from` = `Danny`.
- `key -1 f` then `state` `fold` true and `blocks` smaller than before.
- `key -1 f` again restores the block count.
- `pick -1 keith` then `from` = `Keith`.
- Append a paragraph to the file on disk; after 1 s `total` grew by one.
- The log has no `WARN|ERROR|CRIT` lines other than the two suppressed classes.

- [ ] **Step 3: `tools/shot FILE OUT.png [--from SPEC] [--theme NAME] [--size WxH] [--do "cmd args"…]`**

As OmaWriter's `tools/shot`, with `OMACHANGES_INSTANCE`, `OMACHANGES_STATE_DIR`, `OMAREAD_THEME_DIR` for the theme, running `bin/omachanges --foreground FILE --from SPEC`.

- [ ] **Step 4: `tools/vendor [COMMIT]`**

```bash
#!/usr/bin/env bash
# Move the vendored OmaRead to COMMIT (default: ~/projects/omaread's HEAD).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
commit="${1:-$(git -C ~/projects/omaread rev-parse HEAD)}"
git -C "$ROOT/vendor/omaread" fetch -q local 2>/dev/null || git -C "$ROOT/vendor/omaread" remote add local ~/projects/omaread && git -C "$ROOT/vendor/omaread" fetch -q local
git -C "$ROOT/vendor/omaread" checkout -q "$commit"
echo "vendor/omaread at $commit; commit the submodule pointer."
```

- [ ] **Step 5: `ops/install`, desktop entry, icon**

As OmaWriter's install without the cmake part. Desktop entry `Name=OmaChanges`, `Exec=… %f`, `MimeType=text/markdown;`, `NoDisplay=false`, `StartupWMClass=omachanges`. Icon: a simple SVG, two overlapping page outlines with a tinted stripe, in a single neutral colour so themes do not clash.

- [ ] **Step 6: `HelpSheet.qml`** from OmaRead's `ShortcutSheet.qml` with groups: Read (`j k ↓ ↑`, `Space Shift+Space`, `g g G`, `Ctrl+ Ctrl− Ctrl+0`), Changes (`n p` next and previous change, `f` fold, `v` versions, `o` outline), Find and copy (`Ctrl+F /`, `Enter Shift+Enter`, `Right-click` copy block, `Ctrl+Shift+C`), Window (`Ctrl+W q`, `?`).

- [ ] **Step 7: README and decision record**

README in the shape of OmaWriter's: what it is, one screenshot, Install, Use (the command line and the spec table from the spec), Reading (marks, fold, keys table), Versions (the list), From Claude (one paragraph pointing at the skill), Development table. Six themed screenshots via `tools/shot` into `docs/screenshots/`. `docs/decisions/0001-git-behind-the-launcher.md` records why the window never runs git (the `--resolve` boundary as the version provider).

Run the writing checker on README and the decision record; fix every `[fix]`.

- [ ] **Step 8: Run everything, commit**

```bash
tools/test && tools/check
git add -A && git commit -m "Samples, check and shot tools, install, help sheet and README"
```

### Task 17: The Claude skill

**Files:**
- Create: `~/.claude/skills/omachanges/SKILL.md`

- [ ] **Step 1: Write the skill** in the shape of `~/.claude/skills/open-in-omaread/SKILL.md`: front matter `name: omachanges`, description with the trigger phrases from spec section 9, body with the phrase-to-flags table, the launch (`claude-here omachanges "<PATH>" --from "<SPEC>"`), the check (`hyprctl clients -j | grep '"title": "OmaChanges: <basename>"'`), the log on failure (`~/.local/state/omachanges/qs.log`), and the `--list` path for questions with no window. Description under 1024 characters.

- [ ] **Step 2: Try it**: from this session, run the launch line on a file in the agenta repository with `--from danny` and confirm the window lands on the session's workspace. Then ask the skill's own question path with `--list`.

- [ ] **Step 3: Commit** the skill is outside the repository; note its path in the README's "From Claude" section (done in Task 16) and commit nothing further.

### Task 18: Finish

- [ ] Run `tools/test` and `tools/check` once more in `~/projects/omachanges` and `tools/test` in `~/projects/omaread`.
- [ ] Open the sample comparison on screen with `claude-here bin/omachanges /tmp/omachanges-sample/proposal.md --from danny` and look at it in the current theme and one light theme (`omarchy theme set` is Keith's; use `tools/shot --theme catppuccin-latte` instead).
- [ ] `ops/install` and confirm `omachanges --version` prints `omachanges 0.1.0`.
- [ ] Tag `0.1.0` in `~/projects/omachanges`; push OmaRead if Task 4 was deferred.

## Self-review notes

Spec coverage: section 5 (resolver and job) is Tasks 10 to 12; section 6 (engine) is Tasks 5 to 9; section 7 (rendering) is Tasks 2 to 4; section 8 (window) is Tasks 13 to 15; section 9 (skill) is Task 17; sections 10 and 11 are Task 16. Frontmatter field marks are stored on the fields but only the gutter word renders them, as the spec allows. Removed list items are inserted before the next kept item rather than exactly where they stood when the from side had several in a row; same for removed table rows.
