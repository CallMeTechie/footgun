#!/usr/bin/env bash
# js-review-scope.sh — determine and annotate the JS files to review.
#
# Modes:
#   --list [--include-generated] [path...]    NUL-separated file list on stdout
#   --annotate [--whole-file] <file>          file content with absolute line
#                                             numbers; changed lines marked ">> "
#   --stages [--all]                          annotated content on stdin ->
#                                             TSV "<stage>\t<run|skip>\t<reason>"
#
# Exit codes: 0 = ok, 3 = nothing to review / no such file, 2 = usage error.
set -u

JS_RE='\.(js|jsx|mjs|cjs|ts|tsx)$'
EXCLUDE_RE='(^|/)(node_modules|dist|build|out|coverage|vendor)/|\.min\.js$|\.bundle\.js$'

in_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

# Print changed files (newline-separated) relative to repo root.
# Robust to a repo with no commits: `git diff … HEAD` fails silently and the
# staged (--cached) + untracked sources still yield the set — no empty-tree
# fallback needed.
changed_files() {
  { git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null
    git diff --cached --name-only --diff-filter=ACMR 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
}

# Filter newline-separated list on stdin: JS extensions, optional exclude.
filter_files() {
  local include_generated="$1"
  grep -E "$JS_RE" | {
    if [ "$include_generated" = "1" ]; then cat
    else grep -Ev "$EXCLUDE_RE"; fi
  }
}

cmd_list() {
  local include_generated=0
  local -a paths=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --include-generated) include_generated=1 ;;
      --) shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done; break ;;
      -*) echo "unknown flag: $1" >&2; return 2 ;;
      *) paths+=("$1") ;;
    esac
    shift
  done

  local files
  if [ "${#paths[@]}" -gt 0 ]; then
    files="$(printf '%s\n' "${paths[@]}")"
  elif in_repo; then
    files="$(changed_files)"
  else
    echo "js-review-scope: not a git repo and no paths given" >&2
    return 3
  fi

  files="$(printf '%s\n' "$files" | sed '/^$/d' | filter_files "$include_generated")"
  [ -z "$files" ] && return 3
  # Emit NUL-separated WITHOUT word-splitting (paths may contain whitespace).
  printf '%s\n' "$files" | while IFS= read -r f; do printf '%s\0' "$f"; done
  return 0
}

# Emit the set of NEW-file line numbers that the diff touches.
# Diff against HEAD so STAGED changes are covered too (changed_files() includes
# --cached; without HEAD here, fully-staged edits would yield no markers and the
# reviewers would fall back to whole-file mode). In a repo with no HEAD this
# degrades to an empty set → whole-file mode, which is acceptable for new files.
changed_lines_of() {
  local file="$1"
  local base=HEAD
  git rev-parse --verify HEAD >/dev/null 2>&1 || base=""
  git diff -U0 --no-color $base -- "$file" 2>/dev/null \
    | grep -E '^@@' \
    | sed -E 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+)(,([0-9]+))? @@.*/\2 \4/' \
    | while read -r start cnt; do
        [ -z "$cnt" ] && cnt=1
        [ "$cnt" -eq 0 ] && continue   # pure deletion: no new lines to mark
        local i=0
        while [ "$i" -lt "$cnt" ]; do echo $((start + i)); i=$((i + 1)); done
      done
}

cmd_annotate() {
  local whole_file=0 file=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --whole-file) whole_file=1 ;;
      -*) echo "unknown flag: $1" >&2; return 2 ;;
      *) file="$1" ;;
    esac
    shift
  done
  [ -z "$file" ] && { echo "annotate: missing <file>" >&2; return 2; }
  [ -f "$file" ] || { echo "annotate: no such file: $file" >&2; return 3; }

  # Build the changed-line lookup (skip in whole-file mode or outside a repo).
  local marks=""
  if [ "$whole_file" -eq 0 ] && in_repo; then
    marks="$(changed_lines_of "$file")"
  fi

  awk -v marks="$marks" '
    BEGIN { n = split(marks, a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") chg[a[i]] = 1 }
    { printf "%d: %s%s\n", NR, (NR in chg ? ">> " : ""), $0 }
  ' "$file"
}

# Which reviewer stages the content can actually yield findings for.
#
# correctness and maint run unconditionally: any JS line can be wrong, and any
# JS line can be unreadable. The other three are gated on markers, because a
# diff without a single asynchronous construct cannot produce an async finding,
# and paying a subagent to confirm that is the cost this gate removes.
#
# The marker sets are deliberately generous — they err towards running a stage.
# A gate that is too clever is worse than no gate: the reviewer that would have
# caught the bug never starts, and nothing in the output says so.
ASYNC_RE='async|await|Promise|\.then\(|\.catch\(|\.finally\(|setTimeout|setInterval|setImmediate|queueMicrotask|nextTick|for await|asyncIterator|yield|callback|addEventListener|removeEventListener|\.on\(|\.once\(|\.emit\(|\.subscribe\(|EventEmitter|Worker|postMessage|requestAnimationFrame|requestIdleCallback|AbortController|\.race\(|\.allSettled\(|\.all\(|mutex|lock|race|defer'
SECURITY_RE='fetch\(|XMLHttpRequest|axios|\$\.ajax|innerHTML|outerHTML|dangerouslySetInnerHTML|insertAdjacentHTML|document\.write|eval\(|new Function|setAttribute|execSync|execFile|spawn|child_process|process\.env|localStorage|sessionStorage|indexedDB|document\.cookie|token|passw|secret|credential|apiKey|api_key|jwt|bearer|crypto|hmac|hash|encrypt|decrypt|sanitiz|escapeHtml|querySelector|SELECT |INSERT |UPDATE |DELETE |\.query\(|\.exec\(|knex|sequelize|mongo|redis|path\.join|path\.resolve|readFile|writeFile|unlink|createReadStream|fs\.|req\.|res\.|request\.|response\.|header|cors|origin|redirect|location\.|window\.open|href|postMessage|\.\./|chmod|sudo'
PERF_RE='for *\(|for *await|while *\(|do *\{|\.map\(|\.filter\(|\.reduce\(|\.forEach\(|\.find\(|\.findIndex\(|\.some\(|\.every\(|\.sort\(|\.concat\(|\.splice\(|\.slice\(|\.flat|\.join\(|JSON\.parse|JSON\.stringify|structuredClone|new Array|Array\.from|Object\.keys|Object\.values|Object\.entries|Object\.assign|spread|\.\.\.|RegExp|\.match\(|\.matchAll\(|\.replace\(|querySelectorAll|getElementsBy|createElement|appendChild|insertBefore|innerHTML|useMemo|useCallback|useEffect|render|reflow|offsetWidth|getBoundingClientRect|cache|memo|debounce|throttle'

# stage_reason <label> <regex> <content>
# Emits the TSV row and keeps the matched marker in the reason, so a reader can
# tell a deliberate hit from a lucky substring without re-running the grep.
stage_row() {
  local stage="$1" re="$2" content="$3" hit
  hit="$(printf '%s\n' "$content" | grep -oE "$re" | head -1)"
  if [ -n "$hit" ]; then
    printf '%s\trun\tmatched: %s\n' "$stage" "$hit"
  else
    printf '%s\tskip\tno %s marker in the reviewed lines\n' "$stage" "$stage"
  fi
}

cmd_stages() {
  local all=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --all) all=1 ;;
      -*) echo "unknown flag: $1" >&2; return 2 ;;
      *) echo "stages: unexpected argument: $1" >&2; return 2 ;;
    esac
    shift
  done

  local content changed
  content="$(cat)"

  # Only the lines under review decide. In diff mode that is the ">> " set; a
  # marker in untouched context says nothing about the change being reviewed.
  # With no marked lines at all (whole-file mode, or a repo without HEAD) the
  # whole content counts — narrowing there would be a guess.
  changed="$(printf '%s\n' "$content" | grep -F '>> ' || true)"
  [ -n "$changed" ] || changed="$content"

  if [ "$all" -eq 1 ]; then
    local st
    for st in correctness async security perf maint; do
      printf '%s\trun\t--all was given\n' "$st"
    done
    return 0
  fi

  printf 'correctness\trun\talways: any changed line can be wrong\n'
  stage_row async    "$ASYNC_RE"    "$changed"
  stage_row security "$SECURITY_RE" "$changed"
  stage_row perf     "$PERF_RE"     "$changed"
  printf 'maint\trun\talways: any changed line can be unreadable\n'
  return 0
}

main() {
  [ $# -eq 0 ] && { echo "usage: js-review-scope.sh --list|--annotate|--stages ..." >&2; return 2; }
  local mode="$1"; shift
  case "$mode" in
    --list) cmd_list "$@" ;;
    --annotate) cmd_annotate "$@" ;;
    --stages) cmd_stages "$@" ;;
    *) echo "unknown mode: $mode" >&2; return 2 ;;
  esac
}
main "$@"
