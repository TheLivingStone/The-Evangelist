import {
  safe,
  getKpiOverview,
  getDailySignups,
  getDailyActivity,
  getActivityMix,
  getProductFunnel,
} from "@/lib/analytics";
import { getRecentPulse } from "@/lib/data";
import { fmtRelative } from "@/lib/format";
import KpiCard from "@/components/KpiCard";
import Panel from "@/components/Panel";
import Funnel from "@/components/Funnel";
import MigrationBanner, { ErrorBanner } from "@/components/MigrationBanner";
import { AreaTrend, StackedArea, Donut } from "@/components/charts/Charts";
import { C } from "@/components/charts/theme";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const ACTIVITY_KEYS = ["conversation", "salvation", "prayer", "followup", "church_connection"];

const PULSE_ICON: Record<string, string> = {
  signup: "👤",
  post: "📝",
  church: "⛪",
  salvation: "✝️",
};

export default async function OverviewPage() {
  const [kpiR, signupsR, activityR, mixR, funnelR, pulse] = await Promise.all([
    safe(getKpiOverview),
    safe(() => getDailySignups(30)),
    safe(() => getDailyActivity(30)),
    safe(getActivityMix),
    safe(getProductFunnel),
    getRecentPulse(12).catch(() => []),
  ]);

  const migrationMissing = kpiR.migrationMissing;
  const k = kpiR.data;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Overview</h1>
          <p className="subtitle">The whole mission at a glance — live.</p>
        </div>
        {k && k.live_now > 0 ? (
          <div className="card" style={{ padding: "10px 16px" }}>
            <span className="live-dot" />
            <strong>{k.live_now}</strong>{" "}
            <span className="muted">evangelizing now</span>
          </div>
        ) : null}
      </div>

      {migrationMissing ? <MigrationBanner /> : null}
      {kpiR.error ? <ErrorBanner message={kpiR.error} /> : null}

      {/* KPI strip */}
      {k ? (
        <div className="kpis">
          <KpiCard
            label="Total users"
            value={k.total_users}
            delta={{ now: k.users_7d, prev: k.users_prev_7d }}
            spark={signupsR.data ? { data: signupsR.data, dataKey: "signups" } : undefined}
            accent
          />
          <KpiCard label="New users (7d)" value={k.users_7d} delta={{ now: k.users_7d, prev: k.users_prev_7d }} />
          <KpiCard label="Salvations" value={k.total_salvations} sparkColor={C.green} />
          <KpiCard label="Gospel conversations" value={k.total_conversations} />
          <KpiCard label="Prayers" value={k.total_prayers} />
          <KpiCard
            label="Posts"
            value={k.total_posts}
            delta={{ now: k.posts_7d, prev: k.posts_prev_7d }}
          />
          <KpiCard label="Churches verified" value={`${k.verified_churches} / ${k.total_churches}`} />
          <KpiCard label="Live now" value={k.live_now} hint="evangelizing" sparkColor={C.green} />
        </div>
      ) : null}

      <div className="panels">
        <Panel title="New users" subtitle="Last 30 days" span={1}>
          {signupsR.data ? <AreaTrend data={signupsR.data} dataKey="signups" /> : <Empty />}
        </Panel>

        <Panel title="Activity mix" subtitle="All-time, by type" span={1}>
          {mixR.data ? <Donut data={mixR.data} /> : <Empty />}
        </Panel>

        <Panel title="Kingdom impact over time" subtitle="Activities logged per day, last 30 days" span={2}>
          {activityR.data ? <StackedArea data={activityR.data} keys={ACTIVITY_KEYS} /> : <Empty />}
        </Panel>

        <Panel title="Product funnel" subtitle="From signup to first salvation" span={1}>
          {funnelR.data ? (
            <Funnel
              steps={funnelR.data
                .sort((a, b) => a.step_order - b.step_order)
                .map((s) => ({ label: s.stage, value: s.users }))}
            />
          ) : (
            <Empty />
          )}
        </Panel>

        <Panel title="Live pulse" subtitle="Newest across the app" span={1}>
          {pulse.length === 0 ? (
            <div className="empty">Nothing yet.</div>
          ) : (
            <div className="pulse">
              {pulse.map((p, i) => (
                <div className="pulse-item" key={i}>
                  <div className="pulse-ico">{PULSE_ICON[p.kind] ?? "•"}</div>
                  <div className="pulse-body">
                    <div>{p.label}</div>
                    {p.detail ? <div className="muted" style={{ fontSize: 12 }}>{p.detail}</div> : null}
                  </div>
                  <div className="pulse-time">{fmtRelative(p.at)}</div>
                </div>
              ))}
            </div>
          )}
        </Panel>
      </div>
    </>
  );
}

function Empty() {
  return <div className="empty">No data yet.</div>;
}
