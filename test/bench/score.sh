#!/usr/bin/env bash
# score.sh — deterministischer Eval-Scorer für die footgun-Review-Kette.
#
# Modi:
#   --mode recall <findings.json> <golden.json>   recall/precision/f1 (dirty-Fixture)
#   --mode fp     <findings.json> <golden.json>   False-Positive-Anzahl (clean-Fixture)
#   --self-test                                    eingebaute Assertions, kein LLM
#
# findings.json: [ { "stage": "<key>", "findings": [ { file, line, severity }, ... ] }, ... ]
# golden.json:   [ { "file": "<name>", "line": <int> }, ... ]
# Matching: BASENAME(file) + line mit ±1 Toleranz; stage nicht relevant.
#
# Exit: 0 = ok / Schwelle erfüllt, 1 = Schwelle verfehlt, 2 = Usage-/Tool-Fehler.
set -u
command -v jq >/dev/null || { echo "score.sh: jq erforderlich, aber nicht gefunden" >&2; exit 2; }

RECALL_MIN="${RECALL_MIN:-1.0}"
FP_MAX="${FP_MAX:-0}"

# Kernrechnung: druckt "recall precision f1 fp nF nG" (Leerzeichen-getrennt).
_compute() { # $1=findings.json $2=golden.json
  jq -nr --slurpfile F "$1" --slurpfile G "$2" '
    def base(p): (p | sub(".*/"; ""));
    def absdiff(a;b): (a-b) | if . < 0 then -. else . end;
    ($F[0] | [ .[] as $r | $r.findings[]? | { file: base(.file), line: .line } ]) as $f
    | ($G[0] | [ .[] | { file: base(.file), line: .line } ]) as $g
    | ($f | length) as $nF
    | ($g | length) as $nG
    | ([ $g[] | . as $gi | select( any($f[]; .file==$gi.file and absdiff(.line; $gi.line) <= 1) ) ] | length) as $tpG
    | ([ $f[] | . as $fi | select( any($g[]; .file==$fi.file and absdiff(.line; $fi.line) <= 1) ) ] | length) as $tpF
    | (if $nG > 0 then $tpG/$nG else 1 end) as $recall
    | (if $nF > 0 then $tpF/$nF else 1 end) as $precision
    | (if ($precision+$recall) > 0 then 2*$precision*$recall/($precision+$recall) else 0 end) as $f1
    | ($nF - $tpF) as $fp
    | "\($recall) \($precision) \($f1) \($fp) \($nF) \($nG)"
  '
}

cmd_mode() { # $1=recall|fp $2=findings $3=golden
  local mode="$1" findings="$2" golden="$3"
  [ -f "$findings" ] || { echo "score.sh: keine findings-Datei: $findings" >&2; exit 2; }
  [ -f "$golden" ]   || { echo "score.sh: keine golden-Datei: $golden" >&2; exit 2; }
  local r p f1 fp nF nG
  read -r r p f1 fp nF nG < <(_compute "$findings" "$golden") || { echo "score.sh: jq-Fehler" >&2; exit 2; }
  case "$mode" in
    recall)
      echo "recall=$r precision=$p f1=$f1"
      awk -v r="$r" -v m="$RECALL_MIN" 'BEGIN{ exit !(r+0 >= m+0) }' || return 1 ;;
    fp)
      echo "fp=$fp"
      awk -v fp="$fp" -v m="$FP_MAX" 'BEGIN{ exit !(fp+0 <= m+0) }' || return 1 ;;
    *) echo "score.sh: unbekannter Modus: $mode" >&2; exit 2 ;;
  esac
}

self_test() {
  local tmp; tmp="$(mktemp -d)"; trap "rm -rf '$tmp'" RETURN
  printf '%s' '[{"file":"dirty.js","line":6},{"file":"dirty.js","line":9}]' > "$tmp/g.json"
  printf '%s' '[{"stage":"c","findings":[{"file":"x/dirty.js","line":6},{"file":"dirty.js","line":10}]}]' > "$tmp/f.json"
  local out; out="$(cmd_mode recall "$tmp/f.json" "$tmp/g.json")" || true
  # line 6 trifft golden 6 (exakt); line 10 trifft golden 9 (±1) → recall 2/2=1, precision 2/2=1
  echo "$out" | grep -q 'recall=1 precision=1 f1=1' || { echo "self-test FAIL recall: $out"; return 1; }
  printf '%s' '[]' > "$tmp/ge.json"
  printf '%s' '[{"stage":"s","findings":[{"file":"clean.js","line":5}]}]' > "$tmp/f1.json"
  out="$(cmd_mode fp "$tmp/f1.json" "$tmp/ge.json")" && { echo "self-test FAIL: fp>0 sollte Exit 1 geben"; return 1; }
  echo "$out" | grep -q 'fp=1' || { echo "self-test FAIL fp: $out"; return 1; }
  echo "self-test: PASS"
}

main() {
  [ $# -eq 0 ] && { echo "usage: score.sh --mode recall|fp <findings.json> <golden.json> | --self-test" >&2; exit 2; }
  case "$1" in
    --self-test) self_test ;;
    --mode) shift; [ $# -eq 3 ] || { echo "usage: --mode recall|fp <findings.json> <golden.json>" >&2; exit 2; }
            cmd_mode "$@" ;;
    *) echo "score.sh: unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
}
main "$@"
