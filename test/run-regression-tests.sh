#!/usr/bin/env bash
# Regressions from final whole-branch review (#1 NUL split, #2 staged diff)
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/js-review-scope.sh"

# #1: path with whitespace must be ONE NUL record, not two
t1="$(mktemp -d)"
( cd "$t1"; git init -q; git config user.email t@t; git config user.name t
  echo x > base.js && git add base.js && git commit -q -m init
  printf 'x\n' > "my file.js"; git add -A
  # count NUL-terminated records via tr
  n=$("$SCRIPT" --list | tr -dc '\0' | wc -c)
  [ "$n" -eq 1 ] || { echo "FAIL #1 expected 1 NUL record, got $n"; exit 1; }
  echo "  #1 whitespace path = single NUL record PASS"
) || exit 1

# #2: a STAGED change to line 3 must be marked '>>'
t2="$(mktemp -d)"
( cd "$t2"; git init -q; git config user.email t@t; git config user.name t
  printf 'a\nb\nc\nd\ne\n' > f.js; git add f.js && git commit -q -m init
  printf 'a\nb\nCHANGED\nd\ne\n' > f.js; git add f.js   # STAGE the change
  out="$("$SCRIPT" --annotate f.js)"
  printf '%s\n' "$out" | grep -q '^3: >> CHANGED$' || { echo "FAIL #2 staged change not marked"; printf '%s\n' "$out"; exit 1; }
  echo "  #2 staged change marked '>>' PASS"
) || exit 1

rm -rf "$t1" "$t2"
echo "ALL PASS"
