# Footgun

A multi-stage code-review chain for JavaScript, packaged as a Claude Code plugin.

Instead of a single "look at the code and say something" pass, Footgun runs a
pipeline of focused, read-only reviewers — each hunting one specific class of
JavaScript footgun — then collates everything into one deduplicated report with
a clear verdict. Cheap, mechanical checks run first; expensive, semantic
reviewers run only if the code clears the gate.

```
/footgun                       # review the changed JS files (git diff)
/footgun src/server.js         # review specific files in full
/footgun --include-generated   # don't skip dist/, *.min.js, etc.
```

## Why

- **Sharper findings.** Five isolated, narrowly-scoped reviewers produce cleaner,
  less muddled results than one do-everything prompt.
- **Fail-fast saves work.** If ESLint or Prettier fail on the target files, the
  chain stops before the expensive reviewers ever run.
- **Diff-focused.** By default only the *changed* lines are flagged; the rest of
  the file is context only — no noise from untouched legacy code.
- **Low false-positive rate.** Reviewers are told to leave deliberately-correct
  patterns alone (`x == null` null-checks, intentional `||` fallbacks, mutation
  on a local copy, `JSON.parse` inside `try/catch`, ordered sequential `await`).
- **Read-only.** Footgun reports; it never edits or commits. The chain only runs
  when you ask it to.

## Install

Clone into your Claude Code skills directory — it auto-loads from there:

```bash
git clone https://github.com/CallMeTechie/footgun ~/.claude/skills/footgun
```

Then load it (`/reload-plugins` inside Claude Code, or start a new session). The
plugin loads as `footgun@skills-dir`. Verify with:

```bash
claude plugin validate ~/.claude/skills/footgun
claude plugin details footgun
```

No build step, no runtime dependencies. ESLint / Prettier / `tsc` / `npm audit`
are used only if your project already has them.

## How it works

```
/footgun [path…] [--include-generated]
   │
   ├─ 1. Scope        list changed JS files (extension filter + generated-file exclude)
   ├─ 2. Annotate     emit each file with absolute line numbers; changed lines marked ">> "
   ├─ 3. Big-diff guard  (> 40 files / > 2000 lines → confirm first)
   ├─ 4. Gate         ESLint / Prettier fail-fast · tsc / npm audit non-blocking
   ├─ 5. Fan-out      5 read-only reviewers in parallel
   └─ 6. Aggregate    dedupe → reconcile severity → cross-check blockers → verdict
```

### Review stages

| Stage | Agent | Looks for |
|---|---|---|
| 1. Correctness | `footgun:js-review-correctness` | `==`/`===`, truthiness traps, `this`-binding, loop closures, reference mutation, `parseInt` radix, float math, `??` vs `||`, `JSON.parse` |
| 2. Async | `footgun:js-review-async` | missing `await`, fire-and-forget promises, serial-vs-`Promise.all`, race conditions, missing cancellation, swallowed `.catch` |
| 3. Security | `footgun:js-review-security` | XSS (`innerHTML`/`eval`), prototype pollution, ReDoS, secrets, path traversal, plus a non-blocking `npm audit` sub-check |
| 4. Performance | `footgun:js-review-perf` | memory leaks (listeners/timers/detached DOM), event-loop blocking, re-renders/memoization, stream backpressure |
| 5. Maintainability | `footgun:js-review-maint` | readability, naming, function size, test coverage of changed paths, sensible error types (no `throw 'string'`) |

Each reviewer is read-only and returns only a JSON object:

```json
{ "stage": "security",
  "findings": [
    { "file": "src/render.js", "line": 42,
      "severity": "blocker",
      "issue": "XSS: unsanitized user input assigned to innerHTML",
      "fix": "use textContent, or sanitize before assigning to innerHTML" } ] }
```

### Aggregation & verdict

The aggregator deduplicates by `file`+`line`, reconciles conflicting severities
(highest wins: `blocker > major > minor > nit`), cross-checks each blocker
against the diff, and emits a table plus a verdict:

- **BLOCK** — at least one verified `blocker`.
- **APPROVE WITH NOTES** — otherwise.

Pre-existing issues (e.g. transitive `npm audit` CVEs not introduced by the diff)
are listed but never trigger BLOCK.

## Modes

- **Diff mode** (`/footgun`, no path): only changed (`>> `) lines are flagged;
  the rest of each file is context.
- **Whole-file mode** (`/footgun <path>`): the entire file is reviewed.

## Configuration

Generated and vendored paths are excluded by default: `node_modules/`, `dist/`,
`build/`, `out/`, `coverage/`, `vendor/`, `*.min.js`, `*.bundle.js`, plus
anything matched by `.gitignore`. Pass `--include-generated` to override.

## Standalone scope script

The deterministic core is a plain Bash script you can use on its own:

```bash
# list the JS files that would be reviewed (NUL-separated)
scripts/js-review-scope.sh --list [--include-generated] [path…]

# annotate a file with absolute line numbers + change markers
scripts/js-review-scope.sh --annotate <file>
scripts/js-review-scope.sh --annotate --whole-file <file>
```

Exit codes: `0` ok, `3` nothing to review / no such file, `2` usage error.

## Reminder hook

A non-blocking `PreToolUse` hook nudges you to run `/footgun` when you're about
to `git commit`. It never blocks the commit and never runs the chain
automatically.

## Project layout

```
footgun/
├── .claude-plugin/plugin.json   # manifest
├── commands/footgun.md          # /footgun orchestrator
├── agents/                      # 5 stage reviewers + aggregator
├── hooks/hooks.json             # commit reminder
├── scripts/js-review-scope.sh   # scope + annotation
└── test/                        # bash test suites + fixtures
```

## Tests

```bash
cd ~/.claude/skills/footgun
bash test/run-scope-tests.sh
bash test/run-edge-tests.sh
bash test/run-annotate-tests.sh
bash test/run-regression-tests.sh
```

The `test/fixtures/` pair doubles as a quality check: `dirty.js` (deliberate
footguns → expect BLOCK) and `clean.js` (looks risky, is correct → expect
APPROVE WITH NOTES).

## License

Apache-2.0 — see [LICENSE](LICENSE).
