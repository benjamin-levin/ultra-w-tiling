# Ultra-W Tiling for macOS

This is the macOS companion implementation for Ultra-W Tiling. It is a native Swift/AppKit menu-bar app that uses public macOS APIs:

- Accessibility APIs resize the focused window.
- Carbon global hotkeys switch between 3 through 8 columns.
- A listen-only Core Graphics event tap watches Shift-drag gestures.
- A transparent `NSPanel` draws the drag preview overlay.

## Build

On macOS with Xcode command line tools installed:

```bash
./scripts/build-app.sh
```

The app bundle is written to:

```text
macos/dist/Ultra-W Tiling.app
```

The build script ad-hoc signs the app by default. Set `CODESIGN_IDENTITY` to use a real signing identity.

## Run

Open the app bundle:

```bash
open "dist/Ultra-W Tiling.app"
```

On first run, grant Accessibility permission. If Shift-drag detection does not start, grant Input Monitoring permission as well, then restart the app.

## Usage

- `Command+Option+3` through `Command+Option+8` switch the column count.
- Shift-drag a focused window by its titlebar to select one segment.
- Shift+Control-drag spans from the starting segment to the release segment.
- CapsLock is also treated as a span signal when macOS reports it in event flags, but `Shift+Control` is the reliable macOS modifier.

The app is intentionally menu-bar only. It does not patch WindowServer or use private APIs.
