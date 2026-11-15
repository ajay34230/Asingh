#!/usr/bin/env bash
# One run that checks every performance step and collects data. Usage: GODOT=/path/to/godot tools/dev/check_all.sh
# Prints only the summary lines: import errors, self-test result with the verified perf steps, and the
# frame-time profile with the character running through the farm, bazaar, clinic, police post and centre.
set -u
cd "$(dirname "$0")/../.."
G="${GODOT:-godot}"
OUT="${OUT:-./scratch}"
mkdir -p "$OUT"
"$G" --headless --path . --import > "$OUT/ca_import.log" 2>&1
echo "import script errors: $(grep -c -E 'SCRIPT ERROR|Parse Error' "$OUT/ca_import.log")"
timeout 900 "$G" --headless --fixed-fps 60 --path . -- --selftest > "$OUT/ca_st.log" 2>&1
grep -E "\[selftest\] (PASS|FAIL)|perf steps|\[selftest\] activity" "$OUT/ca_st.log"
echo "selftest script errors: $(grep -c -E 'SCRIPT ERROR|Parse Error' "$OUT/ca_st.log")"
grep -A2 -E "SCRIPT ERROR|Parse Error" "$OUT/ca_st.log" | head -6
PROFILE_RUN=1 timeout 900 "$G" --headless --fixed-fps 60 --path . -- --profile > "$OUT/ca_run.log" 2>&1
grep -E "\[profile\]|occluders:" "$OUT/ca_run.log"
