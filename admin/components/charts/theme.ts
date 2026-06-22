// Chart palette — tied to the app's brand colors (app/lib/core/theme.dart).
// Orange is the lead; the rest mirror the Flutter accent set so charts feel
// like part of the same product.

export const C = {
  accent: "#ff6b00",
  accent2: "#ff8a2b",
  green: "#34d17e",
  blue: "#5b8def",
  purple: "#8b83ff",
  pink: "#f25c9a",
  red: "#e5484d",
  yellow: "#f5c451",
  text: "#ffffff",
  muted: "#8c8c96",
  grid: "#2a2a33",
  surface: "#15151a",
  surface2: "#1e1e25",
};

// Ordered series colors for multi-series charts (stacked areas, multi-bars).
export const SERIES = [
  C.accent,
  C.green,
  C.blue,
  C.purple,
  C.pink,
  C.yellow,
  C.accent2,
];

// Stable color per known category, so the same enum value is the same color
// across every chart (e.g. "salvation" is always green).
export const CATEGORY_COLORS: Record<string, string> = {
  // activity types
  conversation: C.accent,
  salvation: C.green,
  prayer: C.blue,
  followup: C.purple,
  church_connection: C.pink,
  // post types
  testimony: C.green,
  outreach: C.accent,
  update: C.muted,
  update_: C.muted,
  // reactions
  encouraged: C.accent,
  inspired: C.yellow,
  praying: C.blue,
  amen: C.green,
  // platforms
  ios: C.blue,
  android: C.green,
  // claim status
  approved: C.green,
  pending: C.accent,
  rejected: C.red,
  unclaimed: C.muted,
  unknown: C.muted,
};

export function colorFor(key: string, i = 0): string {
  return CATEGORY_COLORS[key?.toLowerCase?.()] ?? SERIES[i % SERIES.length];
}

// Pretty labels for enum-ish keys.
export function prettyLabel(s: string): string {
  if (!s) return "—";
  const cleaned = s.replace(/_$/, "").replace(/_/g, " ");
  return cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
}
