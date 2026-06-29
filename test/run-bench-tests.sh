#!/usr/bin/env bash
# Tests für den Eval-Scorer score.sh.
set -u
SCORE="$(cd "$(dirname "$0")/.." && pwd)/test/bench/score.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

# (1) eingebauter Selbsttest muss bestehen
bash "$SCORE" --self-test >/dev/null || fail "self-test"
echo "  #1 self-test PASS"

# (2) recall-Modus: perfekte Findings → recall=1, precision=1, f1=1
cat > "$tmp/g.json" <<'JSON'
[ { "file": "dirty.js", "line": 6 }, { "file": "dirty.js", "line": 9 } ]
JSON
cat > "$tmp/f_perfect.json" <<'JSON'
[ { "stage": "correctness", "findings": [
  { "file": "test/fixtures/dirty.js", "line": 6, "severity": "major" },
  { "file": "test/fixtures/dirty.js", "line": 9, "severity": "blocker" } ] } ]
JSON
out="$(bash "$SCORE" --mode recall "$tmp/f_perfect.json" "$tmp/g.json")" || fail "recall exit"
echo "$out" | grep -q 'recall=1' || fail "recall!=1: $out"
echo "$out" | grep -q 'precision=1' || fail "precision!=1: $out"
echo "$out" | grep -q 'f1=1' || fail "f1!=1: $out"
echo "  #2 perfect recall PASS ($out)"

# (3) ±1-Toleranz: Finding auf Nachbarzeile zählt als Treffer
cat > "$tmp/f_off1.json" <<'JSON'
[ { "stage": "async", "findings": [ { "file": "dirty.js", "line": 7, "severity": "major" } ] } ]
JSON
cat > "$tmp/g1.json" <<'JSON'
[ { "file": "dirty.js", "line": 6 } ]
JSON
out="$(bash "$SCORE" --mode recall "$tmp/f_off1.json" "$tmp/g1.json")"
echo "$out" | grep -q 'recall=1' || fail "tolerance: $out"
echo "  #3 ±1 tolerance PASS"

# (4) False Positive: Finding ohne Golden-Treffer senkt precision
cat > "$tmp/f_fp.json" <<'JSON'
[ { "stage": "perf", "findings": [
  { "file": "dirty.js", "line": 6, "severity": "minor" },
  { "file": "dirty.js", "line": 99, "severity": "minor" } ] } ]
JSON
out="$(bash "$SCORE" --mode recall "$tmp/f_fp.json" "$tmp/g1.json")"
echo "$out" | grep -q 'precision=0.5' || fail "precision should be 0.5: $out"
echo "  #4 precision with FP PASS ($out)"

# (5) fp-Modus auf clean: leere Findings → fp=0, Exit 0
cat > "$tmp/empty.json" <<'JSON'
[ { "stage": "security", "findings": [] } ]
JSON
cat > "$tmp/golden_empty.json" <<'JSON'
[]
JSON
out="$(bash "$SCORE" --mode fp "$tmp/empty.json" "$tmp/golden_empty.json")" || fail "fp exit on clean"
echo "$out" | grep -q 'fp=0' || fail "fp!=0: $out"
echo "  #5 fp clean PASS"

# (6) fp-Modus: ein Finding auf clean → fp=1, Exit 1
cat > "$tmp/one.json" <<'JSON'
[ { "stage": "security", "findings": [ { "file": "clean.js", "line": 5, "severity": "nit" } ] } ]
JSON
if bash "$SCORE" --mode fp "$tmp/one.json" "$tmp/golden_empty.json" >/dev/null; then
  fail "fp-Modus sollte mit Exit 1 enden, wenn fp>0"
fi
echo "  #6 fp positive → exit 1 PASS"

echo "ALL PASS"
