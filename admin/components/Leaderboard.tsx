import { C } from "./charts/theme";
import type { Leader } from "@/lib/analytics";

const MEDALS = ["🥇", "🥈", "🥉"];

export default function Leaderboard({
  rows,
  unit,
}: {
  rows: Leader[];
  unit: string;
}) {
  if (!rows.length) return <div className="empty">No data yet.</div>;
  const max = Math.max(...rows.map((r) => r.metric), 1);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      {rows.map((r, i) => (
        <div key={r.id} style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ width: 24, textAlign: "center", fontSize: 14, fontWeight: 700, color: C.muted }}>
            {MEDALS[i] ?? i + 1}
          </div>
          {r.avatar_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={r.avatar_url} alt="" className="avatar" />
          ) : (
            <div className="avatar avatar-fallback">
              {(r.full_name || "?").charAt(0).toUpperCase()}
            </div>
          )}
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontWeight: 600, fontSize: 13, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
              {r.full_name || "Unknown"}
            </div>
            <div style={{ height: 5, background: C.surface2, borderRadius: 999, marginTop: 4 }}>
              <div
                style={{
                  width: `${Math.max(3, (r.metric / max) * 100)}%`,
                  height: "100%",
                  background: i === 0 ? C.accent : C.accent2,
                  borderRadius: 999,
                }}
              />
            </div>
          </div>
          <div style={{ fontWeight: 800, fontSize: 14, width: 64, textAlign: "right" }}>
            {r.metric.toLocaleString()}
            <span style={{ color: C.muted, fontWeight: 400, fontSize: 11 }}> {unit}</span>
          </div>
        </div>
      ))}
    </div>
  );
}
