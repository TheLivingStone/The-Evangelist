import { getChurches } from "@/lib/data";
import {
  safe,
  getChurchFruitfulness,
  getMembershipStats,
  getChurchMembers,
  type ChurchMember,
} from "@/lib/analytics";
import { fmtDate } from "@/lib/format";
import { setChurchVerified, rejectChurchClaim } from "@/app/actions";
import KpiCard from "@/components/KpiCard";
import Panel from "@/components/Panel";
import MemberRoster from "@/components/MemberRoster";
import MigrationBanner from "@/components/MigrationBanner";
import { Bars } from "@/components/charts/Charts";
import { C } from "@/components/charts/theme";

export const dynamic = "force-dynamic";
export const revalidate = 0;

function StatusBadge({ verified, claim }: { verified: boolean; claim: string | null }) {
  if (verified) return <span className="badge green">Verified</span>;
  if (claim === "rejected") return <span className="badge gray">Rejected</span>;
  if (claim === "pending") return <span className="badge">Pending review</span>;
  return <span className="badge gray">Unclaimed</span>;
}

export default async function ChurchesPage() {
  const [churches, fruitR, statsR] = await Promise.all([
    getChurches(300),
    safe(() => getChurchFruitfulness(null, 100)),
    safe(getMembershipStats),
  ]);

  const pending = churches.filter(
    (c) => !c.is_verified && c.claim_status === "pending",
  ).length;

  // Pull member rosters only for churches that actually have members.
  const fruit = fruitR.data ?? [];
  const churchesWithMembers = fruit.filter((f) => f.members > 0).map((f) => f.church_id);
  const rosterEntries = await Promise.all(
    churchesWithMembers.map(async (id) => {
      const r = await safe(() => getChurchMembers(id));
      return [id, r.data ?? []] as [string, ChurchMember[]];
    }),
  );
  const rosters = new Map<string, ChurchMember[]>(rosterEntries);
  const memberCount = new Map(fruit.map((f) => [f.church_id, f.members] as const));

  const s = statsR.data;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Churches</h1>
          <p className="subtitle">
            {churches.length} registered · <strong>{pending} awaiting review</strong>.
            Confirm the claimant truly leads the church, then Verify.
          </p>
        </div>
      </div>

      {fruitR.migrationMissing ? <MigrationBanner /> : null}

      {s ? (
        <div className="kpis">
          <KpiCard label="Churches with members" value={s.churches_with_members} accent />
          <KpiCard label="Confirmed members" value={s.confirmed_members} />
          <KpiCard label="Pending members" value={s.pending_members} sparkColor={C.accent} />
          <KpiCard label="Members evangelizing" value={s.members_evangelizing} sparkColor={C.green} />
        </div>
      ) : null}

      {/* The fruitfulness signal: which churches' people actually evangelize. */}
      <div className="panels">
        <Panel
          title="Church fruitfulness"
          subtitle="Ranked by member evangelism (salvations ×5 + conversations ×2 + prayers + follow-ups)"
          span={2}
        >
          {fruit.length === 0 ? (
            <div className="empty">
              No churches have confirmed members with logged activity yet. As members
              join churches and evangelize, the most fruitful churches rise here.
            </div>
          ) : (
            <div className="tablewrap" style={{ border: "none" }}>
              <table>
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Church</th>
                    <th>Members</th>
                    <th>Active</th>
                    <th>Salvations</th>
                    <th>Conversations</th>
                    <th>Score</th>
                  </tr>
                </thead>
                <tbody>
                  {fruit.slice(0, 20).map((f, i) => (
                    <tr key={f.church_id}>
                      <td className="muted">{["🥇", "🥈", "🥉"][i] ?? i + 1}</td>
                      <td>
                        <div style={{ fontWeight: 600 }}>
                          {f.name}{" "}
                          {f.is_verified ? <span className="badge green">✓</span> : null}
                        </div>
                        <div className="muted" style={{ fontSize: 12 }}>{f.city || "—"}</div>
                      </td>
                      <td>{f.members}</td>
                      <td>{f.active_members}</td>
                      <td style={{ color: C.green, fontWeight: 700 }}>{f.salvations}</td>
                      <td>{f.conversations}</td>
                      <td style={{ fontWeight: 800, color: C.accent2 }}>{f.fruitfulness}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Panel>
      </div>

      <h2 style={{ fontSize: 16, margin: "26px 0 14px" }}>
        Directory &amp; vetting{" "}
        {pending > 0 ? <span className="badge">{pending} to review</span> : null}
      </h2>

      <div className="tablewrap">
        {churches.length === 0 ? (
          <div className="empty">No churches registered yet.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Church</th>
                <th>Claimant (for vetting)</th>
                <th>Members</th>
                <th>Status</th>
                <th>Added</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {churches.map((c) => (
                <tr key={c.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>{c.name}</div>
                    <div className="muted" style={{ fontSize: 12 }}>
                      {[c.city, c.address].filter(Boolean).join(" · ") || "—"}
                    </div>
                    {c.service_times ? (
                      <div className="muted" style={{ fontSize: 12 }}>{c.service_times}</div>
                    ) : null}
                    {c.website ? (
                      <a href={c.website} target="_blank" rel="noreferrer" style={{ color: "var(--accent2)", fontSize: 12 }}>
                        {c.website}
                      </a>
                    ) : null}
                  </td>
                  <td>
                    {c.claimant_name ? (
                      <>
                        <div style={{ fontWeight: 600 }}>
                          {c.claimant_name}
                          {c.claimant_role ? <span className="muted"> · {c.claimant_role}</span> : null}
                        </div>
                        {c.claimant_phone ? (
                          <div className="muted" style={{ fontSize: 12 }}>📞 {c.claimant_phone}</div>
                        ) : null}
                        {c.claimant_email ? (
                          <div className="muted" style={{ fontSize: 12 }}>✉️ {c.claimant_email}</div>
                        ) : null}
                        {c.claim_notes ? (
                          <div className="muted" style={{ fontSize: 12, fontStyle: "italic" }}>“{c.claim_notes}”</div>
                        ) : null}
                      </>
                    ) : (
                      <span className="muted">No claimant</span>
                    )}
                  </td>
                  <td>
                    {(memberCount.get(c.id) ?? 0) > 0 ? (
                      <MemberRoster members={rosters.get(c.id) ?? []} />
                    ) : (
                      <span className="muted" style={{ fontSize: 12 }}>—</span>
                    )}
                  </td>
                  <td>
                    <StatusBadge verified={c.is_verified} claim={c.claim_status} />
                  </td>
                  <td className="muted">{fmtDate(c.created_at)}</td>
                  <td>
                    <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                      <form action={setChurchVerified}>
                        <input type="hidden" name="id" value={c.id} />
                        <input type="hidden" name="verified" value={(!c.is_verified).toString()} />
                        <button type="submit" className={c.is_verified ? "btn" : "btn green"}>
                          {c.is_verified ? "Unverify" : "Verify"}
                        </button>
                      </form>
                      {!c.is_verified && c.claim_status !== "rejected" ? (
                        <form action={rejectChurchClaim}>
                          <input type="hidden" name="id" value={c.id} />
                          <button type="submit" className="btn danger">Reject</button>
                        </form>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
