# Tables

A table is a real grid: a tinted header band, hairline rules between rows, generous padding and
column alignment taken from the separator row. Numbers use tabular figures so the digits line up.

## Narrow

| Key | Action |
|-----|--------|
| `j` / `k` | Scroll down / up |
| `g g` / `G` | Top / bottom |
| `Ctrl+F` | Find |
| `?` | Shortcut sheet |

## Aligned

| Left aligned | Centred | Right aligned |
|:-------------|:-------:|--------------:|
| apples | fresh | 1.20 |
| bananas | ripe | 0.35 |
| cherries | *seasonal* | 12.00 |
| dragon fruit | **rare** | 4.75 |
| elderberries | dried | 108.10 |

## Numbers

| Theme | Calls | Answered | Missed | Avg (s) | Uptime |
|:------|------:|---------:|-------:|--------:|-------:|
| Monday | 1,284 | 1,201 | 83 | 41 | 99.98% |
| Tuesday | 1,117 | 1,090 | 27 | 38 | 100.00% |
| Wednesday | 988 | 951 | 37 | 44 | 99.91% |
| Thursday | 1,402 | 1,333 | 69 | 47 | 99.95% |
| Friday | 1,561 | 1,488 | 73 | 52 | 99.99% |

## Wide

This table is wider than the reading column. It scrolls horizontally inside its own frame, with a
fade at the edge to show there is more.

| Decision | Status | Owner | Date | Context | Consequence | Alternatives considered | Follow-up |
|----------|--------|-------|------|---------|-------------|-------------------------|-----------|
| Flat blocks in a ListView | accepted | OmaRead | 2026-09-30 | A 5,000-line document must open in under a second and scroll without dropped frames | Only the blocks on screen are built; nested structure lives inside each block | One rich-text document; a Flickable with every block built up front | Measure the worst scroll step on every release |
| Code colours from the theme | accepted | OmaRead | 2026-09-30 | Built-in highlighting themes almost match the page, which looks worse than not matching at all | A highlighting theme is generated from each Omarchy colors.toml at start-up | The nearest built-in light or dark theme | Regenerate when a new theme appears |
| One reader, many windows | accepted | OmaRead | 2026-09-30 | Several documents are open side by side while an agent works | A single process owns every window; a second launch hands its file over | One process per window | Measure memory with ten windows open |

## Ragged

| One | Two | Three |
|-----|-----|-------|
| only one cell |
| a | b | c | d is extra |
| | | empty first cells |

## Inline content in cells

| Feature | Example | Notes |
|---------|---------|-------|
| Links | [omarchy.org](https://omarchy.org) | Accent colour |
| Code | `md.parse(src, env)` | Chip |
| Emphasis | **bold**, *italic*, ~~struck~~ | All inline styles work |
| Escaped pipe | a \| b | Stays in one cell |
