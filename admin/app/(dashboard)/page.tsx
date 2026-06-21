import { getOverview } from "@/lib/data";

// Server component — runs the aggregate queries with the service role at
// request time. Never cached statically (always reflects live data).
export const dynamic = "force-dynamic";

function Stat({
  label,
  value,
  sub,
}: {
  label: string;
  value: number | string;
  sub?: string;
}) {
  return (
    <div className="card">
      <div className="label">{label}</div>
      <div className="value">{value}</div>
      {sub ? <div className="sub">{sub}</div> : null}
    </div>
  );
}

export default async function OverviewPage() {
  const o = await getOverview();
  return (
    <>
      <h1>Overview</h1>
      <p className="subtitle">Everything across The Evangelist, in one place.</p>

      <div className="cards">
        <Stat
          label="Total users"
          value={o.totalUsers.toLocaleString()}
          sub={o.newUsers7d > 0 ? `+${o.newUsers7d} this week` : undefined}
        />
        <Stat
          label="Salvations"
          value={o.totalSalvations.toLocaleString()}
        />
        <Stat
          label="Gospel conversations"
          value={o.totalConversations.toLocaleString()}
        />
        <Stat
          label="Posts"
          value={o.totalPosts.toLocaleString()}
          sub={o.newPosts7d > 0 ? `+${o.newPosts7d} this week` : undefined}
        />
        <Stat
          label="Churches"
          value={o.totalChurches.toLocaleString()}
        />
        <Stat
          label="Verified churches"
          value={`${o.verifiedChurches} / ${o.totalChurches}`}
        />
      </div>

      <p className="muted">
        Salvations and conversations are summed from every user&apos;s logged
        activity. User emails live in Clerk (not shown here) — see the README to
        wire them in.
      </p>
    </>
  );
}
