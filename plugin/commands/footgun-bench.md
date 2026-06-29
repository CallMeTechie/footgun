---
description: Misst die Review-Qualität der js-review-chain gegen die Fixtures (Recall auf dirty.js, False-Positive-Kontrolle auf clean.js).
argument-hint: ""
---

Du führst den **Eval-Benchmark** der js-review-chain aus. Harte, nummerierte
Prozedur. Scope-Script und Scorer:
- `${CLAUDE_PLUGIN_ROOT}/scripts/js-review-scope.sh`
- `${CLAUDE_PLUGIN_ROOT}/../test/bench/score.sh`
Golden-Dateien unter `${CLAUDE_PLUGIN_ROOT}/../test/bench/expected/`.
Fixtures unter `${CLAUDE_PLUGIN_ROOT}/../test/fixtures/`.

Führe die Schritte **für beide Fixtures** (`dirty.js`, dann `clean.js`) aus.

## 1. Annotieren (Whole-File)
Führe aus:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/js-review-scope.sh" --annotate --whole-file <pfad-zur-fixture>`
Merke dir den annotierten Inhalt.

## 2. Fan-out — fünf Reviewer parallel
Dispatche in **einer einzigen Nachricht** fünf Subagents via Agent-Tool, jeder
mit dem annotierten Inhalt + dem Dateipfad + der Anweisung, ausschließlich seine
Kategorie zu prüfen (Whole-File-Modus — die ganze Datei ist prüfbar):
- `footgun:js-review-correctness`
- `footgun:js-review-async`
- `footgun:js-review-security`
- `footgun:js-review-perf`
- `footgun:js-review-maint`
Jeder liefert `{ "stage": …, "findings": [...] }`.

## 3. Sammeln
Schreibe die fünf zurückgegebenen JSON-Objekte als **ein JSON-Array** in eine
temporäre Datei (z.B. via `cat <<'EOF' > /tmp/footgun_bench_<fixture>.json`).
Das Array hat genau die Form, die `score.sh` erwartet — **kein** manuelles
Flatten nötig, score.sh übernimmt das.

## 4. Scoren
- Für `dirty.js`:
  `bash "${CLAUDE_PLUGIN_ROOT}/../test/bench/score.sh" --mode recall /tmp/footgun_bench_dirty.json "${CLAUDE_PLUGIN_ROOT}/../test/bench/expected/dirty.expected.json"`
- Für `clean.js`:
  `bash "${CLAUDE_PLUGIN_ROOT}/../test/bench/score.sh" --mode fp /tmp/footgun_bench_clean.json "${CLAUDE_PLUGIN_ROOT}/../test/bench/expected/clean.expected.json"`
Der Exit-Code ist **informativ**, kein Abbruchgrund — gib die Zahlen so aus, wie
das Script sie liefert.

## 5. Ausgabe
Gib genau diese Tabelle aus (Werte aus Schritt 4 einsetzen):

```
## footgun Benchmark — Ergebnis

| Fixture  | Recall | Precision | F1  | False Positives |
|----------|--------|-----------|-----|-----------------|
| dirty.js | <r>    | <p>       | <f1>| —               |
| clean.js | —      | —         | —   | <fp>            |
```

Hänge eine Zeile an: `_Hinweis: LLM-Lauf, nicht deterministisch — Werte können über Läufe schwanken._`
