import { Sparkline } from "./charts/Charts";
import { C } from "./charts/theme";

// A headline KPI: big number, optional period-over-period delta, optional
// sparkline. Used across Overview / Growth / Impact.

function Delta({ now, prev }: { now: number; prev: number }) {
  if (prev === 0 && now === 0) return null;
  const pct = prev === 0 ? 100 : Math.round(((now - prev) / prev) * 100);
  const up = now >= prev;
  return (
    <span style={{ color: up ? C.green : C.red, fontSize: 12, fontWeight: 700 }}>
      {up ? "▲" : "▼"} {Math.abs(pct)}%{" "}
      <span style={{ color: C.muted, fontWeight: 400 }}>vs prev</span>
    </span>
  );
}

export default function KpiCard({
  label,
  value,
  delta,
  spark,
  sparkColor = C.accent2,
  accent,
  hint,
}: {
  label: string;
  value: number | string;
  delta?: { now: number; prev: number };
  spark?: { data: any[]; dataKey: string };
  sparkColor?: string;
  accent?: boolean;
  hint?: string;
}) {
  return (
    <div className="card kpi" style={accent ? { borderColor: "rgba(255,107,0,0.4)" } : undefined}>
      <div className="label">{label}</div>
      <div className="value" style={accent ? { color: C.accent2 } : undefined}>
        {typeof value === "number" ? value.toLocaleString() : value}
      </div>
      <div className="kpi-foot">
        {delta ? <Delta now={delta.now} prev={delta.prev} /> : hint ? <span className="muted" style={{ fontSize: 12 }}>{hint}</span> : <span />}
      </div>
      {spark ? (
        <div className="kpi-spark">
          <Sparkline data={spark.data} dataKey={spark.dataKey} color={sparkColor} />
        </div>
      ) : null}
    </div>
  );
}
