# 0011 Touchpad scrolling matched to Chromium

Two-finger scrolling in OmaRead felt slow next to Helium, Keith's Chromium browser. Read from
the sources on 17 October 2026 (Qt 6.11.2, Chromium 154, Hyprland):

- Hyprland forwards a trackpad scroll as `wl_pointer.axis` values in surface pixels, after
  libinput's scroll curve and `scroll_factor`.
- Qt's Wayland plugin (`qtbase/src/plugins/platforms/wayland/qwaylandinputdevice.cpp`) makes
  the wheel event's `pixelDelta` from those values one to one, and `QQuickFlickable` drags by
  `pixelDelta` one to one. It does not fling when the fingers lift: a trackpad scroll stops dead.
- Chromium (`ui/ozone/platform/wayland/host/wayland_pointer.cc`) multiplies the same values by
  12 (`/ 10 * 120`, its wheel-click convention; the `WaylandUnscaledTouchpadScrolling` feature
  that would change this is off by default), and on `axis_stop` starts a fling whose speed
  decays as `dv/dt = -3.7 (v + 172)` (`ui/events/gestures/fling_curve.cc`).

So for the same swipe OmaRead moved a twelfth as far as Helium. Keith's libinput curve
(`scroll_points` in `~/.config/hypr/input.lua`) is tuned for the browser's 12×, which made the
gap worse.

`DocView` now owns the gesture: a `WheelHandler` accepting `Mouse | TouchPad` (Wayland tags a
finger scroll with the mouse device and only marks it synthesised) moves `contentY` by
`pixelDelta × 12` per frame and, on `ScrollEnd`, flings on Chromium's curve from the velocity of
the last three frames, when the lift came within 200 ms of the last movement. A mouse wheel
notch glides 120 px. The ListView is `interactive: false` so its own wheel path cannot add a
second movement, and so a stuck `scrollingPhase` cannot make it steal presses from the blocks.

The factor is `DocView.touchpadScroll`, so an app embedding `MarkdownView` can change it.
