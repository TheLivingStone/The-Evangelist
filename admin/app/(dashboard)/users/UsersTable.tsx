"use client";

import FilterableTable from "@/components/FilterableTable";
import { fmtDate } from "@/lib/format";
import type { ProfileRow } from "@/lib/data";

export default function UsersTable({ users }: { users: ProfileRow[] }) {
  const cities = Array.from(
    new Set(users.map((u) => u.city).filter(Boolean) as string[]),
  ).sort();
  const ministries = Array.from(
    new Set(users.map((u) => u.ministry).filter(Boolean) as string[]),
  ).sort();

  return (
    <FilterableTable<ProfileRow>
      rows={users}
      columns={["Name", "City", "Church", "Streak", "Convos", "Salvations", "Joined"]}
      searchKeys={(u) =>
        `${u.full_name} ${u.username ?? ""} ${u.city ?? ""} ${u.church ?? ""}`
      }
      filters={[
        {
          key: "city",
          label: "Cities",
          options: cities.map((c) => ({ value: c, label: c })),
          match: (u, v) => u.city === v,
        },
        ...(ministries.length
          ? [
              {
                key: "ministry",
                label: "Ministries",
                options: ministries.map((m) => ({ value: m, label: m })),
                match: (u: ProfileRow, v: string) => u.ministry === v,
              },
            ]
          : []),
        {
          key: "activity",
          label: "Activity",
          options: [
            { value: "active", label: "Has activity" },
            { value: "dormant", label: "No activity" },
          ],
          match: (u, v) =>
            v === "active"
              ? u.total_conversations + u.total_salvations + u.total_followups > 0
              : u.total_conversations + u.total_salvations + u.total_followups === 0,
        },
      ]}
      renderRow={(u) => (
        <tr key={u.id}>
          <td>
            <div style={{ fontWeight: 600 }}>{u.full_name}</div>
            {u.username ? (
              <div className="muted" style={{ fontSize: 12 }}>
                @{u.username}
              </div>
            ) : null}
          </td>
          <td className="muted">{u.city || "—"}</td>
          <td className="muted">{u.church || "—"}</td>
          <td>
            {u.current_streak}
            <span className="muted"> / {u.longest_streak}</span>
          </td>
          <td>{u.total_conversations}</td>
          <td>{u.total_salvations}</td>
          <td className="muted">{fmtDate(u.created_at)}</td>
        </tr>
      )}
    />
  );
}
