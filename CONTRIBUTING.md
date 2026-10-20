# Contributing

Keep this project version-specific unless you have tested a port on the target KWin release. KWin internals are not stable plugin APIs.

Before opening a change:

- run `./tools/verify-package.sh`;
- test mode switching with `Meta+Alt+3` through `Meta+Alt+8`;
- test Alt-drag single-segment placement;
- test Alt+Shift-drag multi-segment placement;
- verify existing tiled windows are not resized when changing modes.

Patch changes should stay small and easy to compare with upstream KWin. Avoid broad refactors in the generated KWin patch.
