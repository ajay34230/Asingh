#!/usr/bin/env bash
# Downloads the official Godot export templates matching the pinned editor version,
# verifies them against SHA512-SUMS, and installs them where the editor looks for them.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.4.1}"
TAG="${VERSION}-stable"
BASE="https://github.com/godotengine/godot/releases/download/${TAG}"
TPZ="Godot_v${TAG}_export_templates.tpz"
TARGET="${HOME}/.local/share/godot/export_templates/${VERSION}.stable"

if [ -f "${TARGET}/android_debug.apk" ]; then
  echo "Export templates ${VERSION} already installed."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
curl -fsSL --retry 3 -O "${BASE}/SHA512-SUMS.txt"
curl -fsSL --retry 3 -O "${BASE}/${TPZ}"
grep -F "  ${TPZ}" SHA512-SUMS.txt | sha512sum -c -
unzip -q "$TPZ"
mkdir -p "$TARGET"
mv templates/* "$TARGET"/
echo "Installed templates to ${TARGET}"
ls "$TARGET" | head -20
