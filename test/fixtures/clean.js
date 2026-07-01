// False-Positive-Kontrolle: sieht nach Footgun aus, ist aber korrekt.

// Bewusstes == als Null/Undefined-Check (korrekt)
export function hasValue(x) {
  return x != null; // deckt null UND undefined ab — beabsichtigt
}

// || mit beabsichtigtem Falsy-Fallback (nicht ??)
export function label(name) {
  return name || 'Unbenannt'; // leerer String soll auch 'Unbenannt' ergeben
}

// Köder: .sort() mutiert das Array normalerweise IN-PLACE (klassischer
// Seiteneffekt-Footgun) — hier bewusst auf einer flachen Kopie `[...arr]`, das
// Argument bleibt unangetastet. Der Name macht den numerischen Scope explizit,
// daher ist der Komparator `a - b` korrekt und kein Fehlerfall.
export function sortedNumbers(arr) {
  return [...arr].sort((a, b) => a - b);
}

// JSON.parse innerhalb try/catch
export function safeParse(s) {
  try { return JSON.parse(s); } catch { return null; }
}

// Sequentielles await ist hier gewollt (Reihenfolge wichtig)
export async function migrate(steps) {
  for (const step of steps) {
    await step.run(); // bewusst seriell: jeder Schritt hängt vom vorigen ab
  }
}

// Handgerollte Schleife bewusst: case-insensitive Dedup unter Beibehaltung des
// ersten Vorkommens — das leistet [...new Set()] nicht.
export function uniqueCaseInsensitive(arr) {
  const seen = new Set();
  const out = [];
  for (const x of arr) {
    const key = x.toLowerCase();
    if (!seen.has(key)) { seen.add(key); out.push(x); }
  }
  return out;
}
