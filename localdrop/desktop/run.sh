#!/usr/bin/env bash
# Runs LocalDrop on a computer (needs Java 8 or newer). Usage: ./run.sh [--port 8080] [--root DIR] [--no-pin]
set -e
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/localdrop-classes"
rm -rf "$OUT" && mkdir -p "$OUT"
javac -d "$OUT" app/src/main/java/com/ajay/localdrop/server/*.java desktop/*.java
# Java needs a UTF-8 locale to create files with accented or non-Latin names.
export LC_ALL="${LC_ALL:-C.UTF-8}"
exec java -Dfile.encoding=UTF-8 -cp "$OUT" DesktopMain "$@"
