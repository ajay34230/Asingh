#!/usr/bin/env bash
# Screenshot capture under a virtual display. Usage: GODOT=... tools/dev/run_capture.sh <mode>
# Writes PNGs to $OUT/caps_<mode>/. Needs xvfb-run (apt install xvfb) on Linux.
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="${OUT:-$PWD/scratch}"
mkdir -p "$OUT"
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" \
  --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 \
  --path . -- "--capture-$1=$OUT/caps_$1" > "$OUT/capx_$1.log" 2>&1
echo "exit $?"; ls "$OUT/caps_$1" 2>/dev/null | head -50
