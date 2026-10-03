# 0002 Raw HTML is recognised, never rendered

The spec's example config says `html: false`. With that setting markdown-it does not recognise
HTML at all, so `<!-- SNAPSHOT … -->` headers would print as paragraphs of literal text, and
they must be hidden. OmaRead parses with `html: true` instead, and then never interprets what it
gets:

- `html_block` / `html_inline` that are only comments are dropped.
- An *unclosed* `<!--` is shown, not hidden: markdown-it would otherwise swallow the rest of the
  file into the comment and the document would go blank.
- Everything else is shown literally, as muted monospace (escaped, never passed to Qt as HTML).
- The one exception is `<br>`, which becomes a line break; it is common in tables written by
  agents and harmless.
- The other exception is HTML that is nothing but `<img>` tags, optionally
  wrapped in `<p>`, `<div>`, `<center>` or `<a>` and spaced with `<br>` or `&nbsp;`. It becomes a
  `gallery` block: the images in centred rows that wrap. This is how reports bound for Sakusei
  PDFs and GitHub READMEs put screenshots side by side (`<p><img … style="height:260px"> …</p>`),
  and showing that as source made those documents unreadable. Only `src`, `alt`, `title` and a
  px `width`/`height` (attribute or inline style) are read; images load through the same path
  as Markdown images. Any other tag or any text in the block and it is shown literally as before,
  so nothing beyond images is ever interpreted.
