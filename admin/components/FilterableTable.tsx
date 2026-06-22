"use client";

import { useMemo, useState } from "react";

// A generic client-side filtered table wrapper. The server fetches the rows;
// this filters/searches them in the browser (fast, no extra round-trips for the
// few-hundred-row admin tables). You pass a render function for each row.

export type FilterDef<T> = {
  key: string;
  label: string;
  options: { value: string; label: string }[];
  match: (row: T, value: string) => boolean;
};

export default function FilterableTable<T>({
  rows,
  columns,
  renderRow,
  searchKeys,
  filters = [],
  emptyText = "Nothing matches.",
}: {
  rows: T[];
  columns: string[];
  renderRow: (row: T) => React.ReactNode;
  searchKeys: (row: T) => string;
  filters?: FilterDef<T>[];
  emptyText?: string;
}) {
  const [q, setQ] = useState("");
  const [active, setActive] = useState<Record<string, string>>({});

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return rows.filter((r) => {
      if (needle && !searchKeys(r).toLowerCase().includes(needle)) return false;
      for (const f of filters) {
        const v = active[f.key];
        if (v && v !== "__all" && !f.match(r, v)) return false;
      }
      return true;
    });
  }, [rows, q, active, filters, searchKeys]);

  return (
    <>
      <div className="filterbar">
        <input
          placeholder="Search…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        {filters.map((f) => (
          <select
            key={f.key}
            value={active[f.key] ?? "__all"}
            onChange={(e) => setActive((s) => ({ ...s, [f.key]: e.target.value }))}
          >
            <option value="__all">All {f.label.toLowerCase()}</option>
            {f.options.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        ))}
        <span className="muted" style={{ fontSize: 12, marginLeft: "auto" }}>
          {filtered.length} of {rows.length}
        </span>
      </div>

      <div className="tablewrap">
        {filtered.length === 0 ? (
          <div className="empty">{emptyText}</div>
        ) : (
          <table>
            <thead>
              <tr>
                {columns.map((c) => (
                  <th key={c}>{c}</th>
                ))}
              </tr>
            </thead>
            <tbody>{filtered.map((r) => renderRow(r))}</tbody>
          </table>
        )}
      </div>
    </>
  );
}
