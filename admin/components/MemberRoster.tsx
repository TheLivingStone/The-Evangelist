"use client";

import { useState } from "react";
import { adminConfirmMember, adminRemoveMember } from "@/app/actions";
import type { ChurchMember } from "@/lib/analytics";
import { C } from "./charts/theme";

// Collapsible roster of a church's members (confirmed + pending), with
// confirm/remove actions. Pending members surface first.
export default function MemberRoster({
  members,
}: {
  members: ChurchMember[];
}) {
  const [open, setOpen] = useState(false);
  if (!members.length) {
    return <span className="muted" style={{ fontSize: 12 }}>No members yet</span>;
  }
  const pending = members.filter((m) => m.status === "pending").length;
  const confirmed = members.length - pending;

  return (
    <div>
      <button className="btn" onClick={() => setOpen((o) => !o)} type="button">
        {open ? "▾" : "▸"} {confirmed} member{confirmed === 1 ? "" : "s"}
        {pending > 0 ? (
          <span style={{ color: C.accent2, fontWeight: 700 }}> · {pending} pending</span>
        ) : null}
      </button>
      {open ? (
        <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 8 }}>
          {members.map((m) => (
            <div
              key={m.membership_id}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                padding: "8px 10px",
                background: C.surface2,
                borderRadius: 9,
              }}
            >
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600, fontSize: 13 }}>
                  {m.full_name || "Unknown"}
                  {m.status === "pending" ? (
                    <span className="badge" style={{ marginLeft: 8 }}>pending</span>
                  ) : (
                    <span className="badge green" style={{ marginLeft: 8 }}>confirmed</span>
                  )}
                </div>
                <div className="muted" style={{ fontSize: 12 }}>
                  {m.city || "—"} · {m.total_salvations} saved · {m.total_conversations} talks ·
                  streak {m.current_streak}
                </div>
              </div>
              {m.status === "pending" ? (
                <form action={adminConfirmMember}>
                  <input type="hidden" name="membership_id" value={m.membership_id} />
                  <button type="submit" className="btn green">Confirm</button>
                </form>
              ) : null}
              <form action={adminRemoveMember}>
                <input type="hidden" name="membership_id" value={m.membership_id} />
                <button type="submit" className="btn danger">Remove</button>
              </form>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}
