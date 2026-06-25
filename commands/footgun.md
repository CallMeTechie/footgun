---
description: Mehrstufige JS-Review der geänderten Dateien (oder übergebener Pfade) — Tooling-Gate, 5 parallele Reviewer, Aggregator mit Verdict.
argument-hint: "[pfad…] [--include-generated]"
---

Du orchestrierst die **js-review-chain**. Dies ist eine harte, nummerierte
Prozedur — folge ihr Schritt für Schritt. Das Scope-Script liegt unter
`${CLAUDE_PLUGIN_ROOT}/scripts/js-review-scope.sh` (Fallback-Pfad:
`~/.claude/skills/footgun/scripts/js-review-scope.sh`).

Argumente des Aufrufs: `$ARGUMENTS`

## 1. Scope ermitteln
Führe aus: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/js-review-scope.sh" --list $ARGUMENTS`
- **Exit 3** (oder leere Liste): gib eine freundliche Meldung aus
  („Keine geänderten JS-Dateien gefunden. Nutze `/js-review <pfad>` für eine
  gezielte Prüfung.") und **STOPP** — keine weiteren Schritte.
- Sonst: merke dir die Dateiliste (NUL-getrennt).

Stelle fest, ob es **Pfad-Argument-Modus** ist (ein nicht mit `--` beginnendes
Argument wurde übergeben) → dann ganze Dateien; sonst **Diff-Modus** → nur
geänderte Zeilen.

## 2. Annotieren
Für **jede** Ziel-Datei führe aus:
- Diff-Modus: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/js-review-scope.sh" --annotate <datei>`
- Pfad-Argument-Modus: `… --annotate --whole-file <datei>`
Sammle die annotierten Inhalte (Zeilen mit `<n>: `, geänderte mit `>> `).

## 3. Großer-Diff-Guard
Sind es **> 40 Dateien** oder zusammen **> 2000 annotierte Zeilen**: warne den
Nutzer kurz und frage nach, ob fortgefahren werden soll, **bevor** du Schritt 5
startest.

## 4. Stage 0 — Tooling-Gate (nur vorhandene Tools)
- **ESLint** (falls `eslint` per `npx`/lokal auflösbar UND eine Config existiert
  `.eslintrc*` / `eslint.config.*` / `package.json#eslintConfig`):
  `npx --no-install eslint <ziel-dateien> --max-warnings=0`.
  Schlägt es fehl → zeige den Output und **STOPP** (kein Fan-out).
- **Prettier** (falls auflösbar): `npx --no-install prettier --check <ziel-dateien>`.
  Schlägt es fehl → Output zeigen und **STOPP**.
- **Typecheck** (nur falls `tsconfig.json` existiert): `npx --no-install tsc --noEmit`.
  **Niemals STOPP.** Grep den Output auf die Ziel-Dateipfade; nur die so
  gefilterten Zeilen merkst du als Kontext für Stage 1 vor (ist nichts übrig:
  nichts weitergeben).
- Fehlt ein Tool / keine Config → „skipped (not configured)", weiter.

## 5. Fan-out — fünf Reviewer parallel
Dispatche in **einer einzigen Nachricht** fünf Subagents (damit sie parallel
laufen) via Agent-Tool. Jeder bekommt: die annotierten Inhalte + die Dateipfade
+ die Anweisung, ausschließlich seine Kategorie und nur `>> `-Zeilen zu prüfen.
An `footgun:js-review-correctness` zusätzlich den gefilterten
tsc-Kontext aus Schritt 4 (falls vorhanden) anhängen.

- `footgun:js-review-correctness`
- `footgun:js-review-async`
- `footgun:js-review-security`
- `footgun:js-review-perf`
- `footgun:js-review-maint`

Jeder liefert ein JSON-Objekt `{ "stage": …, "findings": [...] }` zurück.

## 6. Aggregat
Dispatche `footgun:js-review-aggregator` mit (a) den fünf JSON-Objekten
und (b) den annotierten Inhalten (für die Blocker-Gegenprüfung).

## 7. Ausgabe
Gib den Bericht des Aggregators (Markdown-Tabelle + Verdict-Zeile) unverändert an
den Nutzer aus.
