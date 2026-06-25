#!/usr/bin/env bash
# Tests for js-review-scope.sh --annotate
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/js-review-scope.sh"

tmp="$(mktemp -d)"
( cd "$tmp"; git init -q; git config user.email t@t; git config user.name t
  printf 'line1\nline2\nline3\nline4\nline5\n' > f.js
  git add f.js && git commit -q -m init
  # change line 3 only (do not commit)
  printf 'line1\nline2\nCHANGED3\nline4\nline5\n' > f.js

  out="$("$SCRIPT" --annotate f.js)"
  printf '%s\n' "$out" | grep -q '^3: >> CHANGED3$' || { echo "FAIL changed-line marker"; printf '%s\n' "$out"; exit 1; }
  printf '%s\n' "$out" | grep -q '^5: line5$'       || { echo "FAIL plain line 5"; printf '%s\n' "$out"; exit 1; }
  printf '%s\n' "$out" | grep -q '^1: line1$'       || { echo "FAIL plain line 1"; exit 1; }
  echo "  annotate (diff mode) PASS"

  # whole-file mode: no >> markers, all lines numbered
  outw="$("$SCRIPT" --annotate --whole-file f.js)"
  printf '%s\n' "$outw" | grep -q '>>' && { echo "FAIL whole-file should have no markers"; exit 1; }
  printf '%s\n' "$outw" | grep -q '^3: CHANGED3$' || { echo "FAIL whole-file line 3"; exit 1; }
  echo "  annotate (whole-file) PASS"
) || exit 1
rm -rf "$tmp"
echo "ALL PASS"
