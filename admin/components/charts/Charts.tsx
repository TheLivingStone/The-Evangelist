"use client";

import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import { C, SERIES, colorFor, prettyLabel } from "./theme";

// ---- shared bits ------------------------------------------------------------

const axisStyle = { fill: C.muted, fontSize: 11 };

function fmtDay(d: string): string {
  // "2026-06-20" -> "Jun 20"
  const dt = new Date(d + "T00:00:00");
  if (Number.isNaN(dt.getTime())) return d;
  return dt.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function TooltipBox({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div
      style={{
        background: C.surface2,
        border: `1px solid ${C.grid}`,
        borderRadius: 10,
        padding: "8px 11px",
        fontSize: 12,
        boxShadow: "0 8px 24px rgba(0,0,0,0.4)",
      }}
    >
      {label != null && (
        <div style={{ color: C.muted, marginBottom: 4 }}>
          {typeof label === "string" && /^\d{4}-\d{2}-\d{2}/.test(label)
            ? fmtDay(label)
            : label}
        </div>
      )}
      {payload.map((p: any) => (
        <div key={p.dataKey} style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: 2,
              background: p.color || p.fill,
              display: "inline-block",
            }}
          />
          <span style={{ color: C.text }}>
            {prettyLabel(String(p.name))}: <strong>{Number(p.value).toLocaleString()}</strong>
          </span>
        </div>
      ))}
    </div>
  );
}

// ---- Area trend (single or cumulative) -------------------------------------

export function AreaTrend({
  data,
  dataKey = "signups",
  xKey = "day",
  color = C.accent,
  height = 240,
}: {
  data: any[];
  dataKey?: string;
  xKey?: string;
  color?: string;
  height?: number;
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 6, right: 8, left: -16, bottom: 0 }}>
        <defs>
          <linearGradient id={`g-${dataKey}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity={0.5} />
            <stop offset="100%" stopColor={color} stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid stroke={C.grid} strokeDasharray="3 3" vertical={false} />
        <XAxis dataKey={xKey} tick={axisStyle} tickFormatter={fmtDay} axisLine={false} tickLine={false} minTickGap={24} />
        <YAxis tick={axisStyle} axisLine={false} tickLine={false} width={40} allowDecimals={false} />
        <Tooltip content={<TooltipBox />} />
        <Area
          type="monotone"
          dataKey={dataKey}
          stroke={color}
          strokeWidth={2}
          fill={`url(#g-${dataKey})`}
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}

// ---- Stacked area (multi-series over time) ----------------------------------

export function StackedArea({
  data,
  keys,
  xKey = "day",
  height = 280,
}: {
  data: any[];
  keys: string[];
  xKey?: string;
  height?: number;
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 6, right: 8, left: -16, bottom: 0 }}>
        <CartesianGrid stroke={C.grid} strokeDasharray="3 3" vertical={false} />
        <XAxis dataKey={xKey} tick={axisStyle} tickFormatter={fmtDay} axisLine={false} tickLine={false} minTickGap={24} />
        <YAxis tick={axisStyle} axisLine={false} tickLine={false} width={40} allowDecimals={false} />
        <Tooltip content={<TooltipBox />} />
        <Legend
          formatter={(v) => <span style={{ color: C.muted, fontSize: 12 }}>{prettyLabel(v)}</span>}
          iconType="circle"
          iconSize={8}
        />
        {keys.map((k, i) => (
          <Area
            key={k}
            type="monotone"
            dataKey={k}
            name={k}
            stackId="1"
            stroke={colorFor(k, i)}
            fill={colorFor(k, i)}
            fillOpacity={0.78}
            strokeWidth={0}
          />
        ))}
      </AreaChart>
    </ResponsiveContainer>
  );
}

// ---- Donut ------------------------------------------------------------------

export function Donut({
  data,
  height = 240,
}: {
  data: { name: string; value: number }[];
  height?: number;
}) {
  const total = data.reduce((a, b) => a + b.value, 0);
  if (total === 0) return <Empty height={height} />;
  return (
    <ResponsiveContainer width="100%" height={height}>
      <PieChart>
        <Pie
          data={data}
          dataKey="value"
          nameKey="name"
          innerRadius="58%"
          outerRadius="86%"
          paddingAngle={2}
          stroke="none"
        >
          {data.map((d, i) => (
            <Cell key={d.name} fill={colorFor(d.name, i)} />
          ))}
        </Pie>
        <Tooltip content={<TooltipBox />} />
        <Legend
          formatter={(v) => <span style={{ color: C.muted, fontSize: 12 }}>{prettyLabel(v)}</span>}
          iconType="circle"
          iconSize={8}
        />
      </PieChart>
    </ResponsiveContainer>
  );
}

// ---- Horizontal/vertical bar ------------------------------------------------

export function Bars({
  data,
  height = 260,
  horizontal = false,
  color = C.accent,
  perCategoryColor = false,
}: {
  data: { name: string; value: number }[];
  height?: number;
  horizontal?: boolean;
  color?: string;
  perCategoryColor?: boolean;
}) {
  if (!data.length) return <Empty height={height} />;
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart
        data={data}
        layout={horizontal ? "vertical" : "horizontal"}
        margin={{ top: 6, right: 12, left: horizontal ? 8 : -16, bottom: 0 }}
      >
        <CartesianGrid stroke={C.grid} strokeDasharray="3 3" horizontal={!horizontal} vertical={horizontal} />
        {horizontal ? (
          <>
            <XAxis type="number" tick={axisStyle} axisLine={false} tickLine={false} allowDecimals={false} />
            <YAxis type="category" dataKey="name" tick={axisStyle} axisLine={false} tickLine={false} width={110} tickFormatter={prettyLabel} />
          </>
        ) : (
          <>
            <XAxis dataKey="name" tick={axisStyle} axisLine={false} tickLine={false} tickFormatter={prettyLabel} interval={0} angle={-15} textAnchor="end" height={50} />
            <YAxis tick={axisStyle} axisLine={false} tickLine={false} width={40} allowDecimals={false} />
          </>
        )}
        <Tooltip content={<TooltipBox />} cursor={{ fill: "rgba(255,255,255,0.04)" }} />
        <Bar dataKey="value" radius={horizontal ? [0, 6, 6, 0] : [6, 6, 0, 0]} maxBarSize={46}>
          {data.map((d, i) => (
            <Cell key={d.name} fill={perCategoryColor ? colorFor(d.name, i) : color} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}

// ---- Sparkline (tiny, for KPI cards) ---------------------------------------

export function Sparkline({
  data,
  dataKey = "signups",
  color = C.accent2,
  height = 40,
}: {
  data: any[];
  dataKey?: string;
  color?: string;
  height?: number;
}) {
  if (!data?.length) return null;
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data} margin={{ top: 4, right: 2, left: 2, bottom: 0 }}>
        <Line type="monotone" dataKey={dataKey} stroke={color} strokeWidth={2} dot={false} />
      </LineChart>
    </ResponsiveContainer>
  );
}

function Empty({ height }: { height: number }) {
  return (
    <div
      style={{
        height,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        color: C.muted,
        fontSize: 13,
      }}
    >
      No data yet
    </div>
  );
}
