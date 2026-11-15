#!/usr/bin/env bash
# Runs the in-game self-test headless. Usage: GODOT=/path/to/godot tools/dev/run_selftest.sh
# Output: $OUT/st_out.log and $OUT/st_err.log (default OUT=./scratch). Look for "[selftest] PASS".
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="${OUT:-./scratch}"
mkdir -p "$OUT"
timeout 330 "$GODOT" --headless --path . -- --selftest 2> "$OUT/st_err.log" > "$OUT/st_out.log"
echo "exit $?"; grep -E "\[selftest\] (PASS|FAIL)" "$OUT/st_out.log" | tail -5
