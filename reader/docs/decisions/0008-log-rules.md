# 0008 Two log categories are filtered, nothing else

The spec treats QML warnings as bugs. Two warnings are not OmaRead's and cannot be fixed from
QML, so `bin/omaread` (and `tools/screenshot`, `tools/test`) pass `--log-rules` for exactly these
categories:

- `qt.qml.usedbeforedeclared`: Qt's lint for "variable used before its declaration", raised five
  times by the minified `vendor/markdown-it.js`. The code is valid JavaScript (the uses are inside
  functions that run later). Patching minified vendor code would be worse than silencing a lint.
- `qt.qpa.services` (warnings only): "Failed to register with host portal … Connection already
  associated with an application ID". Every Quickshell app logs it in a real Wayland session;
  the running Agentile Factory instance shows the identical line. It happens with or without
  OmaRead's `AppId` pragma.

Quickshell ignores `QT_LOGGING_RULES`, hence the command-line flag. Any other warning still shows,
and `tools/screenshot` fails when one appears.
