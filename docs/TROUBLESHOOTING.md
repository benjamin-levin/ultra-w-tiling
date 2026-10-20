# Troubleshooting

## The Build Cannot Configure

Check the missing package named by CMake. The installer includes the dependency set that was needed for KWin 6.1.5 on the original apt-based Plasma system, but package names can vary between distributions.

Common missing packages from the original build were `kwayland-dev` and `libxcb-util-dev`.

## KWin Version Mismatch

The patch targets KWin 6.1.5. If the installer reports another installed version, stop and port the patch to that exact KWin source before installing.

`ALLOW_VERSION_MISMATCH=1 ./scripts/install.sh` exists for development, not for routine installation.

## The Shortcuts Do Nothing

Log out of Plasma Wayland and log back in after installation. KWin scripts and global shortcut registrations are not always fully reloaded in the current session.

Then confirm the script is enabled in `~/.config/kwinrc`:

```ini
[Plugins]
ultrawidezonesEnabled=true
```

## No Notification Appears

Check that the D-Bus activation file exists:

```bash
ls ~/.local/share/dbus-1/services/org.powerhouse.UltrawideZones.service
```

Then run the service manually to see Python errors:

```bash
~/.local/bin/ultrawidezones-service
```

The service requires Python GI bindings from `python3-gi`.

## Drag Previews Are Overlapping

This usually means stock KWin is running instead of the patched KWin, or the KWin script is active but the native compositor patch is not.

Confirm you logged out and back in after installation. If a distro package upgrade replaced KWin, rerun the installer or reinstall the patched package.

## Alt+Shift Does Not Span

Make sure both Alt and Shift are held during the drag. If Alt-drag moves the window without any outline, check that the KDE window-action modifier (System Settings > Window Management > Window Behavior > Window Actions) is not intercepting it in a way that bypasses interactive move.

The old external input watcher should be disabled:

```bash
systemctl --user is-active ultrawidezones-input-watcher.service
systemctl --user is-enabled ultrawidezones-input-watcher.service
```

Both should report inactive or disabled states.

## Restore The Previous KWin

Run the restore script from the newest backup directory:

```bash
sudo /var/backups/kwin-ultrawidezones-YYYYMMDD-HHMMSS/restore.sh
```

Then log out and back in.

Useful logs:

```bash
journalctl --user -b
journalctl -b
```
