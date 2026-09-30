# 0009 Scrolling long documents without dropped frames

Measured with `qs ipc … call omaread bench -1` (ReaderWindow.debugBench): scroll `long.md`
(5,400 lines, 1,085 top-level blocks) in 120 px steps, forcing the ListView to build delegates
synchronously each step, and time each step.

- Parse: ~45–60 ms. Launch to rendered: ~650 ms including starting qs.
- Mean step: under 1 ms. Before tuning, one step cost 73–82 ms: the first time KSyntaxHighlighting
  highlights with a language it compiles that definition's rules, and the first code block of a
  new language arrived in the cache buffer mid-scroll.
- Fix: `HighlightWarmup.qml` runs a hidden highlighter through the document's languages, one
  every 40 ms, right after the file opens, while the reader is on the first screen. Worst step
  afterwards: 18–19 ms, once per run.

Things tried that did not help and were removed: precompiling the block components
asynchronously; warming only the KSH repository.

The ListView keeps `cacheBuffer` at two screens and `reuseItems` off (delegates differ by type,
so reuse buys little and complicates state such as copy feedback).
