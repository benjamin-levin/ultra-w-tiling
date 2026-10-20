# Ultra-W Tiling for macOS

This is the macOS companion implementation for Ultra-W Tiling. It is a native Swift/AppKit menu-bar app that uses public macOS APIs:

- Accessibility APIs resize the focused window.
- Carbon global hotkeys switch between 2 through 8 columns.
- A listen-only Core Graphics event tap watches Option-drag gestures.
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

Run `scripts/setup-signing.sh` once before the first build. It creates a local signing identity so macOS keeps the app's permissions across rebuilds; ad-hoc signed builds lose them every time.

On first run, grant Accessibility permission. If Option-drag detection does not start, grant Input Monitoring permission as well, then restart the app. The menu bar icon shows `UW` over `!` while a permission is missing, and the menu links to the right Privacy pane.

## Usage

- `Command+Option+2` through `Command+Option+8` switch the column count.
- Option-drag a focused window by its titlebar to select one segment.
- Option+Shift-drag spans from the starting segment to the release segment.

The app is intentionally menu-bar only. It does not patch WindowServer or use private APIs.
