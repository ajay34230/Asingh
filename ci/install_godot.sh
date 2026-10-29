#!/usr/bin/env bash
# Downloads the pinned official Godot editor binary and verifies it against the
# SHA512-SUMS file published with the same GitHub release.
# Usage: ci/install_godot.sh [destination-dir]   (default: .ci/godot)
set -euo pipefail

VERSION="${GODOT_VERSION:-4.4.1}"
TAG="${VERSION}-stable"
DEST="${1:-.ci/godot}"
BASE="https://github.com/godotengine/godot/releases/download/${TAG}"
ZIP="Godot_v${TAG}_linux.x86_64.zip"
BIN="Godot_v${TAG}_linux.x86_64"

mkdir -p "$DEST"
cd "$DEST"
if [ -x "$BIN" ]; then
  echo "Godot ${VERSION} already present."
  exit 0
fi
curl -fsSL --retry 3 -O "${BASE}/SHA512-SUMS.txt"
curl -fsSL --retry 3 -O "${BASE}/${ZIP}"
grep -F "  ${ZIP}" SHA512-SUMS.txt | sha512sum -c -
unzip -q -o "$ZIP"
chmod +x "$BIN"
"./$BIN" --version
