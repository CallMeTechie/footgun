#!/usr/bin/env bash
# Test harness for js-review-scope.sh --stages (the fan-out gate).
#
# The gate exists to stop paying for a reviewer whose category cannot occur in
# the reviewed lines. Its one unacceptable failure is the opposite of a wasted
# agent: a stage skipped on code that does contain a finding of that kind. The
# dirty.js case below is that guard and must never be weakened to make the gate
# look better.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$(dirname "$HERE")/plugin/scripts/js-review-scope.sh"
fail=0
ok() { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; fail=1; }

verdict() { printf '%s\n' "$2" | grep -E "^$1	" | cut -f2; }

# --- correctness and maint are unconditional -------------------------------
out="$(printf '1: >> const TIMEOUT_MS = 30;\n' | bash "$SCRIPT" --stages)"
[ "$(verdict correctness "$out")" = "run" ] && ok "correctness always runs" || bad "correctness was gated"
[ "$(verdict maint "$out")" = "run" ] && ok "maint always runs" || bad "maint was gated"

# --- a bare constant cannot yield async, security or perf findings ----------
for st in async security perf; do
  [ "$(verdict "$st" "$out")" = "skip" ] && ok "$st skipped on a bare constant" \
    || bad "$st ran on a line with no $st marker"
done

# --- recall guard: the bench fixture must still get all five ---------------
# dirty.js carries a planted finding for every category (missing await, XSS via
# innerHTML, listener leak, O(n^2) dedup). A skip here is a lost finding.
out="$(bash "$SCRIPT" --annotate --whole-file "$HERE/fixtures/dirty.js" | bash "$SCRIPT" --stages)"
for st in correctness async security perf maint; do
  [ "$(verdict "$st" "$out")" = "run" ] && ok "dirty.js: $st runs" \
    || bad "dirty.js: $st was skipped although the fixture plants a $st finding"
done

# --- only the reviewed lines decide ----------------------------------------
# A marker in untouched context says nothing about the change under review;
# counting it would make the gate no gate at all on any large file.
out="$(printf '1: el.innerHTML = userInput;\n2: >> const n = 1;\n' | bash "$SCRIPT" --stages)"
[ "$(verdict security "$out")" = "skip" ] \
  && ok "marker in unchanged context does not arm a stage" \
  || bad "an unchanged context line armed the security stage"

# --- no markers at all: whole content counts, no narrowing -----------------
# Whole-file mode and a repo without HEAD both produce unmarked content.
# Narrowing there would be a guess, so the gate must not narrow.
out="$(printf '1: el.innerHTML = userInput;\n' | bash "$SCRIPT" --stages)"
[ "$(verdict security "$out")" = "run" ] \
  && ok "unmarked content is judged whole" || bad "unmarked content was narrowed"

# --- --all is the escape hatch ---------------------------------------------
out="$(printf '1: >> const n = 1;\n' | bash "$SCRIPT" --stages --all)"
n_run="$(printf '%s\n' "$out" | grep -c '	run	')"
[ "$n_run" = "5" ] && ok "--all runs all five" || bad "--all ran $n_run of 5"

# --- usage errors ----------------------------------------------------------
printf '' | bash "$SCRIPT" --stages --bogus 2>/dev/null; [ "$?" = "2" ] \
  && ok "unknown flag exits 2" || bad "unknown flag did not exit 2"

[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
