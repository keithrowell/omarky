# Commons and Ui: copied from the Omarchy shell

These files are copies, not originals. Refresh them from the Omarchy shell rather
than editing them, and keep the one local change below.

| File | Copied from | Date |
|---|---|---|
| `Commons/Border.qml` | `~/.local/share/omarchy/shell/Commons/Border.qml` | 2026-09-30 |
| `Commons/BorderGeometry.js` | `~/.local/share/omarchy/shell/Commons/BorderGeometry.js` | 2026-09-30 |
| `Commons/ShellColor.qml` | `~/.local/share/omarchy/shell/Commons/Color.qml`, renamed because Qt 6.12 adds a `Color` object to QtQuick that hides a singleton of that name | 2026-09-30 |
| `Commons/Style.qml` | `~/.local/share/omarchy/shell/Commons/Style.qml` | 2026-09-30 |
| `Commons/Util.qml` | `~/.local/share/omarchy/shell/Commons/Util.qml` | 2026-09-30 |
| `Commons/qmldir` | `~/.local/share/omarchy/shell/Commons/qmldir` | 2026-09-30 |
| `Ui/BorderOverlay.qml` | `~/.local/share/omarchy/shell/Ui/BorderOverlay.qml` | 2026-09-30 |
| `Ui/BorderSurface.qml` | `~/.local/share/omarchy/shell/Ui/BorderSurface.qml` | 2026-09-30 |
| `Ui/PanelToolTip.qml` | `~/.local/share/omarchy/shell/Ui/PanelToolTip.qml` | 2026-09-30 |

Omarchy revision at copy time: `f632d26b` (2026-08-23).

`Util.qml` is Omarchy's version. The Factory's copy (`~/lab/factory/ui/Commons/Util.qml`)
adds an `execArgv()` helper; OmarkyReader does not need it, so it keeps the upstream file.

`Ui/qmldir` is trimmed to the three components OmarkyReader uses.

## Local change

`ShellColor.qml` line 18: `currentThemePath` reads `OMARKY_THEME_DIR` first, so the app
(and `tools/screenshot`) can render under any theme directory without touching the
real theme. Re-apply this one line after a refresh.
