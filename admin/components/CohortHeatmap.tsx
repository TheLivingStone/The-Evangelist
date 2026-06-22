import { C } from "./charts/theme";
import type { CohortRow } from "@/lib/analytics";

// Weekly retention heatmap. Rows = signup-week cohorts, columns = weeks since
// signup, cell color intensity = % of that cohort still active that week.
// This is the single best read on whether a campaign brought *real* users.

function cellColor(pct: number): string {
  if (pct <= 0) return C.surface2;
  // Interpolate surface2 -> accent by retention %.
  const t = Math.min(1, pct / 100);
  // accent #ff6b00
  const r = Math.round(30 + (255 - 30) * t);
  const g = Math.round(30 + (107 - 30) * t);
  const b = Math.round(37 + (0 - 37) * t);
  return `rgb(${r},${g},${b})`;
}

function weekLabel(iso: string): string {
  const d = new Date(iso + "T00:00:00");
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

export default function CohortHeatmap({ rows }: { rows: CohortRow[] }) {
  if (!rows.length) {
    return <div className="empty">No cohort data yet.</div>;
  }
  // Pivot: cohort_week -> { offset -> retention }, plus size.
  const cohorts = new Map<string, { size: number; cells: Map<number, number> }>();
  let maxOffset = 0;
  for (const r of rows) {
    if (!cohorts.has(r.cohort_week))
      cohorts.set(r.cohort_week, { size: r.cohort_size, cells: new Map() });
    cohorts.get(r.cohort_week)!.cells.set(r.week_offset, r.retention);
    if (r.week_offset > maxOffset) maxOffset = r.week_offset;
  }
  const offsets = Array.from({ length: maxOffset + 1 }, (_, i) => i);
  const sorted = Array.from(cohorts.entries()).sort((a, b) => (a[0] < b[0] ? 1 : -1));

  const th: React.CSSProperties = {
    color: C.muted,
    fontSize: 11,
    fontWeight: 700,
    padding: "6px 8px",
    textAlign: "center",
    whiteSpace: "nowrap",
  };

  return (
    <div style={{ overflowX: "auto" }}>
      <table style={{ borderCollapse: "separate", borderSpacing: 4, width: "100%" }}>
        <thead>
          <tr>
            <th style={{ ...th, textAlign: "left" }}>Cohort (week of)</th>
            <th style={th}>Users</th>
            {offsets.map((o) => (
              <th key={o} style={th}>
                W{o}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {sorted.map(([week, info]) => (
            <tr key={week}>
              <td style={{ fontSize: 12, fontWeight: 600, whiteSpace: "nowrap", paddingRight: 8 }}>
                {weekLabel(week)}
              </td>
              <td style={{ fontSize: 12, color: C.muted, textAlign: "center" }}>{info.size}</td>
              {offsets.map((o) => {
                const pct = info.cells.get(o);
                const has = pct != null;
                return (
                  <td
                    key={o}
                    title={has ? `${pct}% active in week ${o}` : ""}
                    style={{
                      background: has ? cellColor(pct!) : "transparent",
                      borderRadius: 6,
                      width: 46,
                      height: 30,
                      textAlign: "center",
                      fontSize: 11,
                      fontWeight: 700,
                      color: has && pct! > 45 ? "#fff" : C.muted,
                    }}
                  >
                    {has ? `${pct}%` : ""}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
