id: 3f2a9c1e-7b4d-4e8a-9c01-5d6e7f8a9b0c
title: Bare front matter
teaser: Metadata as key and value lines at the top of the file, with no fences, ended by the first blank line.
tags: Rendering, Samples
thread:
author: OmarkyReader maintainers
published: yes
published_at: 2026-10-04 09:30

# Bare front matter

Some files carry their metadata as bare `key: value` lines, one per line, with no `---` fences.
MultiMarkdown calls this metadata; static blogs often use it. The block ends at the first blank
line, and OmarkyReader draws it as the same card as YAML front matter.

A key with nothing after it, such as `thread:` above, shows as a faint dash.
