#!/usr/bin/env bash
# Edge-case tests for js-review-scope.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/js-review-scope.sh"

# (a) fresh repo, NO commit (no HEAD), untracked new.js -> listed
ta="$(mktemp -d)"
( cd "$ta"; git init -q; git config user.email t@t; git config user.name t
  echo n > new.js
  out="$("$SCRIPT" --list 2>/dev/null)"
  printf '%s' "$out" | grep -qz 'new.js' || { echo "FAIL (a) no-HEAD new.js missing"; exit 1; }
  echo "  (a) no-HEAD fallback PASS"
) || exit 1

# (b) only generated file changed -> exit 3
tb="$(mktemp -d)"
( cd "$tb"; git init -q; git config user.email t@t; git config user.name t
  echo x > base.js && git add base.js && git commit -q -m init
  mkdir dist; echo d > dist/d.js; git add -A
  "$SCRIPT" --list >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 3 ] || { echo "FAIL (b) expected exit 3, got $rc"; exit 1; }
  echo "  (b) generated-only -> exit 3 PASS"
) || exit 1

# (c) outside any git repo, no path arg -> exit 3, no crash
tc="$(mktemp -d)"   # plain dir, NOT a git repo
( cd "$tc"
  "$SCRIPT" --list >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 3 ] || { echo "FAIL (c) expected exit 3, got $rc"; exit 1; }
  echo "  (c) non-repo -> exit 3 PASS"
) || exit 1

rm -rf "$ta" "$tb" "$tc"
echo "ALL PASS"
