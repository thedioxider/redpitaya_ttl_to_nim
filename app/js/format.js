const UNITS = [
  [1, "ps"],
  [1e3, "ns"],
  [1e6, "µs"],
];

// 3 significant digits in ns/us, whole ps, with "~" if rounded.
export function formatTime(ps) {
  let [scale, unit] = UNITS[0];
  // Pick the unit after rounding, so 999.6 ps reads "~1 ns", not "~1000 ps".
  const rounded = Math.abs(Number(ps.toPrecision(3)));
  for (const u of UNITS) {
    if (rounded >= u[0]) [scale, unit] = u;
  }
  const value = ps / scale;
  const shown =
    unit === "ps" ? Math.round(value) : Number(value.toPrecision(3));
  return `${shown === value ? "" : "~"}${shown} ${unit}`;
}

export function formatCoarse(ps) {
  const ns = Math.round(ps / 1e3);
  const us = Math.floor(ns / 1e3);
  return `${us ? `${us} µs ` : ""}${ns % 1e3} ns`;
}

// -> [whole us, ns to 1 decimal]
export function splitTotal(ps) {
  const tenthsNs = Math.round(ps / 100);
  return [Math.floor(tenthsNs / 1e4), (tenthsNs % 1e4) / 10];
}

export function formatFine(ps) {
  return `${Number((ps / 1e3).toFixed(2))} ns`;
}

// Non-negative decimal, empty is 0; null if unparsable.
export function parseAmount(text) {
  const s = text.trim().replace(",", ".");
  if (!s) return 0;
  return /^(\d+\.?\d*|\.\d+)$/.test(s) ? Number(s) : null;
}

export function maxSteps(bits) {
  return 2 ** bits - 1;
}

export function scaleLabel(title, perStepPs) {
  return `${title}: ${formatTime(perStepPs)}/step`;
}
