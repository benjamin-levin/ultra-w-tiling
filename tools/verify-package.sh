#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$ROOT/patches/kwin-6.6.6-ultrawide-zones.patch"
JS_FILE="$ROOT/kwin-script/ultrawidezones/contents/code/main.js"
SERVICE_FILE="$ROOT/service/ultrawidezones-service"

search() {
  if command -v rg >/dev/null 2>&1; then
    rg -q "$1" "$2"
  else
    grep -Eq "$1" "$2"
  fi
}

echo "Checking shell syntax"
bash -n "$ROOT/scripts/install.sh"
bash -n "$ROOT/scripts/build-ultrawidezones-kwin.sh"
bash -n "$ROOT/macos/scripts/build-app.sh"
bash -n "$ROOT/tools/verify-package.sh"

echo "Checking service syntax"
python3 - "$SERVICE_FILE" <<'PY'
from pathlib import Path
import ast
import sys

ast.parse(Path(sys.argv[1]).read_text())
PY

if command -v node >/dev/null 2>&1; then
  echo "Checking KWin script syntax"
  node --check "$JS_FILE"
else
  echo "Skipping KWin script syntax check because node is not installed"
fi

echo "Checking KWin patch markers"
search 'quickTileSpanGeometry' "$PATCH_FILE"
search 'QSizeF\(0\.10, 0\.10\)' "$PATCH_FILE"
search 'QTimer::singleShot' "$PATCH_FILE"

if [[ "$(uname -s)" == "Darwin" ]] && command -v swift >/dev/null 2>&1; then
  echo "Checking macOS Swift package"
  swift build --package-path "$ROOT/macos"
else
  echo "Skipping macOS Swift build because this host is not macOS with Swift"
fi

echo "Package verification passed"
