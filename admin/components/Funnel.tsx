import { C } from "./charts/theme";

// A simple, readable funnel: each stage is a bar whose width is proportional to
// the top stage, with the absolute count and the conversion vs. the prior step.

export default function Funnel({
  steps,
  colors = [C.accent, C.accent2, C.blue, C.green],
}: {
  steps: { label: string; value: number }[];
  colors?: string[];
}) {
  const top = steps[0]?.value || 1;
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      {steps.map((s, i) => {
        const widthPct = Math.max(4, Math.round((s.value / top) * 100));
        const prev = i === 0 ? null : steps[i - 1].value;
        const conv = prev && prev > 0 ? Math.round((s.value / prev) * 100) : null;
        const color = colors[i % colors.length];
        return (
          <div key={s.label}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
              <span style={{ fontSize: 13, fontWeight: 600 }}>{s.label}</span>
              <span style={{ fontSize: 13 }}>
                <strong>{s.value.toLocaleString()}</strong>
                {conv != null ? (
                  <span style={{ color: C.muted }}> · {conv}% of prev</span>
                ) : null}
              </span>
            </div>
            <div style={{ background: C.surface2, borderRadius: 8, height: 26, overflow: "hidden" }}>
              <div
                style={{
                  width: `${widthPct}%`,
                  height: "100%",
                  background: `linear-gradient(90deg, ${color}, ${color}cc)`,
                  borderRadius: 8,
                  transition: "width 0.4s ease",
                }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}
