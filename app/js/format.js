const UNITS = [
  [1, "ps"],
  [1e3, "ns"],
  [1e6, "µs"],
];

// 3 significant digits in ns/µs, whole ps, with "~" if rounded.
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

export function maxSteps(bits) {
  return 2 ** bits - 1;
}

export function scaleLabel(title, perStepPs) {
  return `${title} · ${formatTime(perStepPs)}/step`;
}
