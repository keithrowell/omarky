# 0001 The editor is painted by a native QSyntaxHighlighter

Status: accepted, 22 Oct 2026.

## Decision

The editor is one plain-text `TextEdit`, and a small C++ QML module (`native/`, `OmaWriter.Native`) paints it. `MarkdownHighlighter` is a `QSyntaxHighlighter` on the TextEdit's document. It sets character formats for the Markdown it finds and block formats for line height and hanging indents. Everything else in OmaWriter is QML and plain JavaScript, like OmaRead.

## Why

The look Keith asked for needs three things QML alone cannot do on an editable text:

| Need | Pure QML |
|---|---|
| Faded marks, bold, italic, code chips and links inside a line, kept live while typing | KSyntaxHighlighting can colour a TextEdit, but its themes cannot size headings or tell a mark from the text it wraps |
| Line height | `TextEdit` has no line-height property, and the document's block format is out of reach from QML |
| Marks hanging in the margin | Needs a per-line left margin and negative text indent, also block formats |

The other routes were worse. A rich-text TextEdit rebuilt from HTML on every keystroke moves the cursor and splits paragraphs unpredictably, and odd paragraph handling is what Keith disliked about Omawrite. A block-per-paragraph editor turns Enter and Backspace across paragraphs into custom code and loses native selection across them. A web view was ruled out for OmaRead (size, and it breaks under Quickshell), and the same reasons hold.

## Consequences

The source stays the file, character for character, because the highlighter only paints. Spell checking comes from Sonnet (KDE's library, already installed) inside the same pass, since a document takes one highlighter. The module is built with CMake on first launch and again when its sources change. It links Qt's private GUI headers for one flag, which ties the build to the installed Qt version (decision 0002).
