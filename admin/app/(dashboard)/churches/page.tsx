import { getChurches } from "@/lib/data";
import { fmtDate } from "@/lib/format";
import { setChurchVerified, rejectChurchClaim } from "@/app/actions";

export const dynamic = "force-dynamic";

function StatusBadge({
  verified,
  claim,
}: {
  verified: boolean;
  claim: string | null;
}) {
  if (verified) return <span className="badge green">Verified</span>;
  if (claim === "rejected") return <span className="badge gray">Rejected</span>;
  if (claim === "pending") return <span className="badge">Pending review</span>;
  return <span className="badge gray">Unclaimed</span>;
}

export default async function ChurchesPage() {
  const churches = await getChurches();
  const pending = churches.filter(
    (c) => !c.is_verified && c.claim_status === "pending",
  ).length;

  return (
    <>
      <h1>Churches</h1>
      <p className="subtitle">
        {churches.length} registered · <strong>{pending} awaiting your
        review</strong>. Contact the claimant to confirm they truly lead the
        church, then Verify. Verifying marks it trusted in the app.
      </p>

      <div className="tablewrap">
        {churches.length === 0 ? (
          <div className="empty">No churches registered yet.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Church</th>
                <th>Claimant (for vetting)</th>
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
                      <div className="muted" style={{ fontSize: 12 }}>
                        {c.service_times}
                      </div>
                    ) : null}
                    {c.website ? (
                      <a
                        href={c.website}
                        target="_blank"
                        rel="noreferrer"
                        style={{ color: "var(--accent2)", fontSize: 12 }}
                      >
                        {c.website}
                      </a>
                    ) : null}
                  </td>
                  <td>
                    {c.claimant_name ? (
                      <>
                        <div style={{ fontWeight: 600 }}>
                          {c.claimant_name}
                          {c.claimant_role ? (
                            <span className="muted">
                              {" "}
                              · {c.claimant_role}
                            </span>
                          ) : null}
                        </div>
                        {c.claimant_phone ? (
                          <div className="muted" style={{ fontSize: 12 }}>
                            📞 {c.claimant_phone}
                          </div>
                        ) : null}
                        {c.claimant_email ? (
                          <div className="muted" style={{ fontSize: 12 }}>
                            ✉️ {c.claimant_email}
                          </div>
                        ) : null}
                        {c.claim_notes ? (
                          <div
                            className="muted"
                            style={{ fontSize: 12, fontStyle: "italic" }}
                          >
                            “{c.claim_notes}”
                          </div>
                        ) : null}
                      </>
                    ) : (
                      <span className="muted">No claimant</span>
                    )}
                  </td>
                  <td>
                    <StatusBadge
                      verified={c.is_verified}
                      claim={c.claim_status}
                    />
                  </td>
                  <td className="muted">{fmtDate(c.created_at)}</td>
                  <td>
                    <div
                      style={{ display: "flex", gap: 6, flexWrap: "wrap" }}
                    >
                      <form action={setChurchVerified}>
                        <input type="hidden" name="id" value={c.id} />
                        <input
                          type="hidden"
                          name="verified"
                          value={(!c.is_verified).toString()}
                        />
                        <button
                          type="submit"
                          className={c.is_verified ? "btn" : "btn green"}
                        >
                          {c.is_verified ? "Unverify" : "Verify"}
                        </button>
                      </form>
                      {!c.is_verified && c.claim_status !== "rejected" ? (
                        <form action={rejectChurchClaim}>
                          <input type="hidden" name="id" value={c.id} />
                          <button type="submit" className="btn danger">
                            Reject
                          </button>
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
