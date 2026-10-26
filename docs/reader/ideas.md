# Ideas for consideration

Not planned and not promised. Notes on things that might be worth doing later.

## Render Sakusei's Vue components

Sakusei (the markdown-to-PDF pipeline) lets a document embed Vue components from its style pack,
written as `<vue-component … />` tags. OmaRead shows those tags as raw source today, so a
Sakusei document reads worse here than in its PDF.

Some ways in, roughly from cheapest to dearest:

- **Native stand-ins.** Recognise known component tags the way `<img>`-only HTML is recognised
  (docs/decisions/0002) and draw a native QML block for each: a card, a callout, a stat row. This
  would be a small, fixed list kept in step with the style packs. No JavaScript runs.
- **Pre-rendered images.** Ask Sakusei to render each component to a PNG or SVG and show the
  image. This is faithful, but it needs Sakusei installed and a build step on every reload.
- **A real Vue runtime.** This is ruled out by the spec's "no WebEngine" non-goal (docs/spec.md §1).

To find out first: which components Keith's documents actually use, and whether a handful of
native stand-ins would cover them.
