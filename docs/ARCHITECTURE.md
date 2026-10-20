# Architecture

Ultra-W Tiling has separate Linux/KWin and macOS implementations because the window-management APIs are completely different.

## macOS Backend

The macOS backend in `macos/` is a native Swift/AppKit menu-bar app.

Runtime pieces:

- `AppController` owns the menu-bar item, mode selection, permissions prompt, hotkeys, and gesture watcher.
- `HotkeyController` registers `Command+Option+2` through `Command+Option+8` with Carbon global hotkeys.
- `GestureController` installs a listen-only Core Graphics event tap and watches Option-drag gestures that begin in the focused window's titlebar.
- `OverlayController` displays a transparent non-activating `NSPanel` over the active screen and draws segment previews.
- `AccessibilityWindowController` reads and writes the focused window frame through AXUIElement Accessibility attributes.
- `ZoneEngine` contains the shared horizontal segment math.

The macOS backend does not use private APIs and does not patch WindowServer. It needs Accessibility permission to move windows and may need Input Monitoring permission for the event tap.

Option-drag selects one segment and Option+Shift-drag spans segments.

## Linux/KWin Backend

KWin Ultrawide Zones has three runtime pieces and one build-time piece.

## Native KWin Patch

`patches/kwin-6.6.6-ultrawide-zones.patch` changes KWin internals so the compositor owns the drag behavior:

- uses Alt instead of Shift to trigger KWin's custom-tile drag outline;
- lowers KWin's custom tile minimum width from `0.15` to `0.10`, which allows 7 and 8 equal columns;
- latches Alt at move start for single-segment tiling;
- latches Alt+Shift for span tiling;
- computes the span geometry from the drag start and current pointer position;
- applies the final span geometry after KWin finishes its normal move flow.

This native patch is the important part. Earlier script-only attempts fought KWin's built-in Shift overlay, which caused overlapping previews, mismatched drop geometry, and occasional conflicting snap behavior.

## KWin Script

`kwin-script/ultrawidezones` registers the user shortcuts and rebuilds the live KWin tile layout for 2 through 8 equal horizontal columns.

The active responsibilities are:

- register `Meta+Alt+2` through `Meta+Alt+8`;
- call the D-Bus service when the mode changes;
- rebuild each screen's root tile layout with zero padding;
- detach and restore already tiled windows so a mode switch does not resize the current set of windows;
- register auxiliary move/grow/shrink shortcuts.

The older drag outline functions remain in the script but are disconnected. `connectWindowSignals(window)` intentionally returns immediately because native KWin now handles drag preview and drop.

## D-Bus Service

`service/ultrawidezones-service` owns `org.powerhouse.UltrawideZones` on the session bus.

It provides:

- `SetMode(int32 count) -> bool`;
- `GetMode() -> int32`;
- `Ping() -> bool`.

`SetMode` writes the selected mode into `~/.config/kwinrc`, rewrites KWin tiling layout entries to the chosen equal-column count, calls KWin reconfigure, and sends a desktop notification.

The service exits after a short idle timeout and is normally launched by the D-Bus service file installed at `~/.local/share/dbus-1/services/org.powerhouse.UltrawideZones.service`.

## Installer

`scripts/install.sh` is intentionally self-contained. It downloads KWin 6.6.6, applies the bundled patch, builds KWin, stages the install, backs up every overwritten `/usr` file, then atomically replaces the staged files.

The atomic replacement matters. Copying directly over `libkwin.so` while KWin is running can truncate the active library and crash the session. The installer copies each staged file to a hidden temporary path in the destination directory, then moves it into place.
