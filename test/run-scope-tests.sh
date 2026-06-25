#!/usr/bin/env bash
# Test harness for js-review-scope.sh (plain bash; bats not available)
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/js-review-scope.sh"
fail() { echo "FAIL: $1"; exit 1; }

# --- Test 1: extension filter + generated-file exclude ---
tmp="$(mktemp -d)"
(
  cd "$tmp"
  git init -q
  git config user.email t@t; git config user.name t
  echo x > base.js && git add base.js && git commit -q -m init
  mkdir -p dist
  echo a > a.js; echo b > b.ts; echo c > c.txt
  echo d > dist/d.js; echo m > x.min.js
  git add -A
  out="$("$SCRIPT" --list)"
  printf '%s' "$out" | grep -qz 'a.js'      || { echo "FAIL a.js missing"; exit 1; }
  printf '%s' "$out" | grep -qz 'b.ts'      || { echo "FAIL b.ts missing"; exit 1; }
  printf '%s' "$out" | grep -qz 'c.txt'     && { echo "FAIL c.txt leaked"; exit 1; }
  printf '%s' "$out" | grep -qz 'dist/d.js' && { echo "FAIL dist leaked"; exit 1; }
  printf '%s' "$out" | grep -qz 'x.min.js'  && { echo "FAIL min leaked"; exit 1; }
  echo "  test1 (extension+exclude) PASS"
) || fail "test1"

# --- Test 2: --include-generated re-includes dist/min ---
(
  cd "$tmp"
  out="$("$SCRIPT" --list --include-generated)"
  printf '%s' "$out" | grep -qz 'dist/d.js' || { echo "FAIL dist not re-included"; exit 1; }
  printf '%s' "$out" | grep -qz 'x.min.js'  || { echo "FAIL min not re-included"; exit 1; }
  echo "  test2 (--include-generated) PASS"
) || fail "test2"

rm -rf "$tmp"
echo "ALL PASS"
