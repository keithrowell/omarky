# 0006 Syntax colours generated from colors.toml

KSyntaxHighlighting's QML API can only use a theme that exists on disk when its `Repository`
first loads, and it cannot be told to reload. Picking the nearest built-in theme would give
gruvbox code colours that almost, but not quite, match the page.

So `services/Highlight.qml` generates one KSH theme per Omarchy theme at startup
(`lib/kshtheme.js`, unit-tested) from every `colors.toml` under
`~/.local/share/omarchy/themes` and `~/.config/omarchy/themes` (plus `OMAREAD_THEME_DIR`),
writes them to `~/.local/share/omaread/ksh/org.kde.syntax-highlighting/themes/`, and only then
lets code blocks load the highlighter. `bin/omaread` (and `tools/screenshot`) prepend
`~/.local/share/omaread/ksh` to `XDG_DATA_DIRS` so KSH finds them. They stay out of
`~/.local/share/org.kde.syntax-highlighting`, so Kate and friends never list them.

Mapping: keywords, control flow and imports magenta; functions blue; strings green; numbers,
constants, chars and preprocessor orange; types and attributes yellow; built-ins cyan; operators
dim; comments faint italic; errors red. A live theme switch picks the pre-generated theme of the
new name; a theme created after launch falls back to KSH's default light or dark theme until the
next start.

The module is detected by looking for its `qmldir` on the QML import path, so a missing
`syntax-highlighting` package leaves plain monospace code and nothing in the log.

Code is rendered as rich text with one `<p>` per source line (`lib/code.js`), so it gets a fixed
1.5 line height; KSH still sees one text block per line and keeps multi-line state (docstrings,
block comments). Empty lines carry a no-break space, because Qt drops empty paragraphs.
