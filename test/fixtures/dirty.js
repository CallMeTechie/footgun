// Recall-Fixture: je Stage genau ein klarer Footgun.

// Stage 1 — Correctness
export function parseId(x) {
  if (x == null) return 0;          // ok (intentional null-check) — NICHT flaggen
  return parseInt(x);               // FOOTGUN: parseInt ohne Radix
}
export function pick(a) {
  if (a = 1) return a;              // FOOTGUN: Zuweisung in Bedingung (= statt ===)
  return 0;
}

// Stage 2 — Async
export async function load(api) {
  const p = api.fetchUser();        // FOOTGUN: fehlendes await
  return p.name;
}

// Stage 3 — Security
export function render(el, userInput) {
  el.innerHTML = userInput;         // FOOTGUN: XSS via innerHTML
}

// Stage 4 — Perf
export function attach(node, handler) {
  node.addEventListener('click', handler); // FOOTGUN: kein removeEventListener / Leak
}

// Stage 5 — Maintainability
export function boom() {
  throw 'kaputt';                   // FOOTGUN: throw string
}

// Stage 6 — Over-Engineering
export function unique(arr) {
  const out = [];
  for (const x of arr) {
    if (!out.includes(x)) out.push(x); // FOOTGUN: handgerollte Dedup statt [...new Set(arr)]
  }
  return out;
}
