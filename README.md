# KWin Ultrawide Zones

KWin Ultrawide Zones is a Plasma/KWin 6.1.5 customization for 32:9 displays. It makes KWin's native Shift-drag tiling overlay behave like a fast horizontal zone picker for 3 through 8 equal columns.

The current behavior is:

- `Meta+Alt+3` through `Meta+Alt+8` switch the active drag grid and show a desktop notification.
- Shift-drag previews and drops a window into the single segment under the pointer.
- Shift+CapsLock-drag previews and drops a window across every segment from the drag start segment to the release segment.
- Existing tiled windows are preserved when switching modes.
- The old external input watcher is disabled; modifier detection happens inside KWin.

This repository contains a KWin script, a small D-Bus activation service, and a native KWin patch. The native patch is required because the stock KWin Shift overlay is owned by KWin itself, not by JavaScript KWin scripts.

## Supported Target

This is currently version-locked to KWin 6.1.5 on an apt-based Plasma 6 system. It was built for a local Plasma Wayland setup where KWin reports version `6.1.5`.

Do not apply the patch blindly to another KWin release. KWin has no stable internal ABI for this kind of compositor patch.

## Install

Run from the repository root:

```bash
./scripts/install.sh
```

The installer downloads KWin 6.1.5 source, applies `patches/kwin-6.1.5-ultrawide-zones.patch`, builds it, stages it, backs up overwritten `/usr` files under `/var/backups/kwin-ultrawidezones-*`, installs the KWin script and D-Bus service into your home directory, and enables the shortcut defaults.

After the installer finishes, log out of Plasma Wayland and log back in.

Useful environment variables:

- `NOCONFIRM=1` skips the interactive prompt.
- `WORKDIR=/path` changes the build workspace.
- `SRC=/path/to/kwin-v6.1.5` uses an existing KWin source tree.
- `ALLOW_VERSION_MISMATCH=1` bypasses the installed KWin version guard.

## Usage

Use `Meta+Alt+3`, `Meta+Alt+4`, `Meta+Alt+5`, `Meta+Alt+6`, `Meta+Alt+7`, or `Meta+Alt+8` to choose the segmentation count.

Hold Shift while dragging a window to select one segment.

Hold Shift+CapsLock while dragging a window to span multiple adjacent segments. Start the drag over the first desired segment and release over the last desired segment.

## Restore

Each install writes a restore script under the newest `/var/backups/kwin-ultrawidezones-*` directory:

```bash
sudo /var/backups/kwin-ultrawidezones-YYYYMMDD-HHMMSS/restore.sh
```

Log out and back in after restoring. Reinstalling the distro KWin package also replaces the patched compositor files.

## License

GPL-2.0-or-later. The patch modifies KWin GPL-2.0-or-later source files and remains under the same license.
