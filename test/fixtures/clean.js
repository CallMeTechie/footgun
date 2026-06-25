// False-Positive-Kontrolle: sieht nach Footgun aus, ist aber korrekt.

// Bewusstes == als Null/Undefined-Check (korrekt)
export function hasValue(x) {
  return x != null; // deckt null UND undefined ab — beabsichtigt
}

// || mit beabsichtigtem Falsy-Fallback (nicht ??)
export function label(name) {
  return name || 'Unbenannt'; // leerer String soll auch 'Unbenannt' ergeben
}

// Mutierende Methode auf lokaler Kopie (kein Seiteneffekt)
export function sorted(arr) {
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
