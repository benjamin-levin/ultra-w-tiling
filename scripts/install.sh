#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KWIN_VERSION="${KWIN_VERSION:-6.6.6}"
KWIN_TARBALL_URL="${KWIN_TARBALL_URL:-https://invent.kde.org/plasma/kwin/-/archive/v${KWIN_VERSION}/kwin-v${KWIN_VERSION}.tar.gz}"
WORKDIR="${WORKDIR:-/tmp/kwin-ultrawide-zones}"
DEFAULT_SRC="$WORKDIR/kwin-v${KWIN_VERSION}"
SRC="${SRC:-$DEFAULT_SRC}"
BUILD="${BUILD:-$WORKDIR/build}"
STAGE="${STAGE:-$WORKDIR/stage}"
CONFIG_LOG="${CONFIG_LOG:-$WORKDIR/configure.log}"
BUILD_LOG="${BUILD_LOG:-$WORKDIR/build.log}"
PATCH_FILE="$REPO_ROOT/patches/kwin-${KWIN_VERSION}-ultrawide-zones.patch"

packages=(
  build-essential
  cmake
  curl
  dbus-user-session
  gettext
  extra-cmake-modules
  hwdata
  kscreenlocker-dev
  kwin-dev
  kwayland-dev
  libcanberra-dev
  libcap-dev
  libdisplay-info-dev
  libdrm-dev
  libegl-dev
  libeis-dev
  libepoxy-dev
  libfontconfig-dev
  libfreetype-dev
  libgbm-dev
  libglib2.0-bin
  libinput-dev
  libkf6auth-dev
  libkf6colorscheme-dev
  libkf6config-dev
  libkf6configwidgets-dev
  libkf6coreaddons-dev
  libkf6crash-dev
  libkf6dbusaddons-dev
  libkf6declarative-dev
  libkf6globalaccel-dev
  libkf6guiaddons-dev
  libkf6i18n-dev
  libkf6idletime-dev
  libkf6kcmutils-dev
  libkf6newstuff-dev
  libkf6notifications-dev
  libkf6package-dev
  libkf6service-dev
  libkf6svg-dev
  libkf6widgetsaddons-dev
  libkf6windowsystem-dev
  libkf6xmlgui-dev
  libkdecorations3-dev
  libkglobalacceld-dev
  knighttime-dev
  libkpipewire-dev
  liblcms2-dev
  libpipewire-0.3-dev
  libplasma-dev
  libplasmaactivities-dev
  libsystemd-dev
  libudev-dev
  libwayland-dev
  libx11-dev
  libx11-xcb-dev
  libxcb-composite0-dev
  libxcb-cursor-dev
  libxcb-damage0-dev
  libxcb-dri3-dev
  libxcb-glx0-dev
  libxcb-icccm4-dev
  libxcb-image0-dev
  libxcb-keysyms1-dev
  libxcb-present-dev
  libxcb-randr0-dev
  libxcb-render0-dev
  libxcb-res0-dev
  libxcb-shape0-dev
  libxcb-shm0-dev
  libxcb-sync-dev
  libxcb-util-dev
  libxcb-xfixes0-dev
  libxcb-xinerama0-dev
  libxcb-xinput-dev
  libxcb-xkb-dev
  libxcvt-dev
  libxkbcommon-dev
  libxkbcommon-x11-dev
  ninja-build
  patch
  pkg-config
  plasma-wayland-protocols
  python3-gi
  qt6-5compat-dev
  qt6-base-dev
  qt6-base-private-dev
  qt6-declarative-dev
  qt6-declarative-private-dev
  qt6-svg-dev
  qt6-sensors-dev
  qt6-tools-dev
  qt6-wayland-dev
  qt6-wayland-private-dev
  wayland-protocols
  xwayland
)

say() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

detected_kwin_version() {
  if command -v kwin_wayland >/dev/null 2>&1; then
    kwin_wayland --version 2>/dev/null | awk '{print $NF; exit}'
    return
  fi

  if command -v kwin_x11 >/dev/null 2>&1; then
    kwin_x11 --version 2>/dev/null | awk '{print $NF; exit}'
    return
  fi
}

confirm() {
  local installed_version
  installed_version="$(detected_kwin_version || true)"

  if [[ -n "$installed_version" && "$installed_version" != "$KWIN_VERSION" && "${ALLOW_VERSION_MISMATCH:-0}" != "1" ]]; then
    die "Installed KWin appears to be $installed_version, but this patch targets $KWIN_VERSION. Set ALLOW_VERSION_MISMATCH=1 only if you know the ABI risk."
  fi

  if [[ "${NOCONFIRM:-0}" == "1" ]]; then
    return
  fi

  cat <<EOF
This will build and install a patched KWin $KWIN_VERSION over package-managed KWin files.

The installer will:
  - install build dependencies with apt
  - download KWin $KWIN_VERSION source if SRC is not already set
  - apply $PATCH_FILE
  - build and stage the patched KWin
  - back up overwritten /usr files under /var/backups/kwin-ultrawidezones-*
  - atomically replace the staged KWin files in /usr
  - install the Ultrawide Zones KWin script and D-Bus service in your home directory
  - enable Meta+Alt+3 through Meta+Alt+8 shortcuts
  - disable the older external input watcher service, if it exists

You must log out of Plasma Wayland and log back in after this finishes.
EOF

  read -r -p "Continue? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) exit 0 ;;
  esac
}

install_dependencies() {
  say "Validating sudo"
  sudo -v

  say "Updating apt metadata"
  sudo apt-get update

  say "Installing KWin build dependencies"
  sudo apt-get install -y "${packages[@]}"
}

prepare_source() {
  local tarball="$WORKDIR/kwin-v${KWIN_VERSION}.tar.gz"

  [[ -f "$PATCH_FILE" ]] || die "Missing patch file: $PATCH_FILE"
  mkdir -p "$WORKDIR"

  if [[ ! -f "$SRC/CMakeLists.txt" ]]; then
    say "Downloading KWin $KWIN_VERSION source"
    if [[ "$SRC" != "$DEFAULT_SRC" ]]; then
      die "SRC was set to $SRC, but it does not look like a KWin source tree"
    fi
    rm -rf "$DEFAULT_SRC"
    curl -L --fail "$KWIN_TARBALL_URL" -o "$tarball"
    tar -xzf "$tarball" -C "$WORKDIR"
  fi

  [[ -f "$SRC/CMakeLists.txt" ]] || die "KWin source tree not found: $SRC"

  if grep -q 'quickTileSpanGeometry' "$SRC/src/window.cpp"; then
    say "KWin source is already patched"
    return
  fi

  say "Applying Ultrawide Zones KWin patch"
  patch -d "$SRC" -p1 < "$PATCH_FILE"
}

verify_patched_source() {
  grep -q 'quickTileSpanGeometry' "$SRC/src/window.cpp" || die "KWin source is missing the Alt+Shift span patch"
  grep -q 'QSizeF(0.10, 0.10)' "$SRC/src/tiles/tile.h" || die "KWin source is missing the smaller custom tile minimum"
}

configure_build() {
  mkdir -p "$WORKDIR"
  say "Configuring patched KWin"
  cmake \
    -S "$SRC" \
    -B "$BUILD" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_TESTING=OFF \
    2>&1 | tee "$CONFIG_LOG"
}

build_kwin() {
  say "Building patched KWin"
  cmake --build "$BUILD" --parallel "$(nproc)" 2>&1 | tee "$BUILD_LOG"
}

stage_install() {
  say "Staging install into $STAGE"
  rm -rf "$STAGE"
  DESTDIR="$STAGE" cmake --install "$BUILD"
  [[ -d "$STAGE/usr" ]] || die "Staged install did not produce $STAGE/usr"
}

install_staged_files() {
  local backup
  backup="/var/backups/kwin-ultrawidezones-$(date +%Y%m%d-%H%M%S)"

  say "Backing up overwritten files to $backup"
  sudo mkdir -p "$backup"
  while IFS= read -r -d '' staged; do
    local dest
    dest="${staged#$STAGE}"
    if [[ -e "$dest" || -L "$dest" ]]; then
      sudo cp -a --parents "$dest" "$backup"
    fi
  done < <(find "$STAGE" \( -type f -o -type l \) -print0)

  sudo tee "$backup/restore.sh" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
sudo cp -a "$backup/usr/." /usr/
sudo ldconfig
echo "Restored KWin files from $backup"
echo "Log out and back in for the restore to take effect."
EOF
  sudo chmod +x "$backup/restore.sh"

  say "Installing patched KWin files with atomic replacement"
  while IFS= read -r -d '' staged_dir; do
    local dest_dir
    dest_dir="${staged_dir#$STAGE}"
    sudo mkdir -p "$dest_dir"
  done < <(find "$STAGE/usr" -type d -print0)

  while IFS= read -r -d '' staged; do
    local dest parent base tmp
    dest="${staged#$STAGE}"
    parent="$(dirname "$dest")"
    base="$(basename "$dest")"
    tmp="$parent/.${base}.ultrawidezones.$$"
    sudo rm -rf "$tmp"
    sudo cp -a "$staged" "$tmp"
    sudo mv -Tf "$tmp" "$dest"
  done < <(find "$STAGE/usr" \( -type f -o -type l \) -print0)
  sudo ldconfig

  say "Backup created at $backup"
}

install_user_files() {
  local script_src="$REPO_ROOT/kwin-script/ultrawidezones"
  local script_dest="$HOME/.local/share/kwin/scripts/ultrawidezones"
  local service_src="$REPO_ROOT/service/ultrawidezones-service"
  local service_dest="$HOME/.local/bin/ultrawidezones-service"
  local dbus_dir="$HOME/.local/share/dbus-1/services"
  local dbus_file="$dbus_dir/org.powerhouse.UltrawideZones.service"

  say "Installing Ultrawide Zones KWin script and D-Bus service"
  [[ -f "$script_src/metadata.json" ]] || die "Missing script package: $script_src"
  [[ -f "$service_src" ]] || die "Missing D-Bus service: $service_src"

  mkdir -p "$(dirname "$script_dest")" "$(dirname "$service_dest")" "$dbus_dir"
  rm -rf "$script_dest"
  cp -a "$script_src" "$script_dest"
  install -m 0755 "$service_src" "$service_dest"

  cat > "$dbus_file" <<EOF
[D-BUS Service]
Name=org.powerhouse.UltrawideZones
Exec=$service_dest
EOF

  python3 - "$HOME/.config/kwinrc" "$HOME/.config/kglobalshortcutsrc" <<'PY'
from pathlib import Path
import sys

kwinrc = Path(sys.argv[1])
shortcuts = Path(sys.argv[2])


def read_lines(path):
    if path.exists():
        return path.read_text().splitlines()
    return []


def write_lines(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def section_bounds(lines, section):
    header = f"[{section}]"
    start = None
    for index, line in enumerate(lines):
        if line == header:
            start = index
            break
    if start is None:
        return None, None
    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].startswith("["):
            end = index
            break
    return start, end


def set_key(lines, section, key, value):
    start, end = section_bounds(lines, section)
    entry = f"{key}={value}"
    if start is None:
        if lines and lines[-1] != "":
            lines.append("")
        lines.extend([f"[{section}]", entry])
        return lines

    prefix = f"{key}="
    for index in range(start + 1, end):
        if lines[index].startswith(prefix):
            lines[index] = entry
            return lines

    lines.insert(end, entry)
    return lines


def get_key(lines, section, key):
    start, end = section_bounds(lines, section)
    if start is None:
        return None

    prefix = f"{key}="
    for index in range(start + 1, end):
        if lines[index].startswith(prefix):
            return lines[index][len(prefix):]
    return None


kwin_lines = read_lines(kwinrc)
mode = get_key(kwin_lines, "UltrawideZones", "mode")
if mode not in {"3", "4", "5", "6", "7", "8"}:
    mode = "3"
kwin_lines = set_key(kwin_lines, "Plugins", "ultrawidezonesEnabled", "true")
kwin_lines = set_key(kwin_lines, "UltrawideZones", "mode", mode)
write_lines(kwinrc, kwin_lines)

shortcut_values = {
    "UltrawideZones3": "Meta+Alt+3,none,Ultrawide Zones: 3 Columns",
    "UltrawideZones4": "Meta+Alt+4,none,Ultrawide Zones: 4 Columns",
    "UltrawideZones5": "Meta+Alt+5,none,Ultrawide Zones: 5 Columns",
    "UltrawideZones6": "Meta+Alt+6,none,Ultrawide Zones: 6 Columns",
    "UltrawideZones7": "Meta+Alt+7,none,Ultrawide Zones: 7 Columns",
    "UltrawideZones8": "Meta+Alt+8,none,Ultrawide Zones: 8 Columns",
    "UltrawideZonesSpanDrag": "none,none,Ultrawide Zones: Span Drag",
    "UltrawideZonesShiftDrag": "none,none,Ultrawide Zones: Shift Drag",
    "UltrawideZonesReleaseDrag": "none,none,Ultrawide Zones: Release Drag",
}
shortcut_lines = read_lines(shortcuts)
for key, value in shortcut_values.items():
    shortcut_lines = set_key(shortcut_lines, "kwin", key, value)
write_lines(shortcuts, shortcut_lines)
PY
}

disable_external_watcher() {
  say "Disabling old external input watcher, if present"
  systemctl --user disable --now ultrawidezones-input-watcher.service >/dev/null 2>&1 || true
}

validate_user_files() {
  say "Validating installed user files"
  python3 - "$HOME/.local/bin/ultrawidezones-service" <<'PY'
from pathlib import Path
import ast
import sys

ast.parse(Path(sys.argv[1]).read_text())
PY
  if command -v node >/dev/null 2>&1; then
    node --check "$HOME/.local/share/kwin/scripts/ultrawidezones/contents/code/main.js"
  fi
}

reconfigure_kwin() {
  say "Requesting KWin reconfigure"
  busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
}

main() {
  confirm
  install_dependencies
  prepare_source
  verify_patched_source
  configure_build
  build_kwin
  stage_install
  install_staged_files
  install_user_files
  disable_external_watcher
  validate_user_files
  reconfigure_kwin

  cat <<EOF

Done.

Next steps:
  1. Log out of Plasma Wayland and log back in.
  2. Use Meta+Alt+3 through Meta+Alt+8 to switch column count.
  3. Alt-drag selects one segment.
  4. Alt+Shift-drag spans from the first segment to the segment under the pointer.

Configure log: $CONFIG_LOG
Build log:     $BUILD_LOG
EOF
}

main "$@"
