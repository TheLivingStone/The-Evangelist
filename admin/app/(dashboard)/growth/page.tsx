import {
  safe,
  getDailySignups,
  getSignupsBySource,
  getSignupsByCity,
  getPlatformSplit,
  getActivationRate,
  getCohortRetention,
  getProductFunnel,
} from "@/lib/analytics";
import Panel from "@/components/Panel";
import KpiCard from "@/components/KpiCard";
import Funnel from "@/components/Funnel";
import CohortHeatmap from "@/components/CohortHeatmap";
import SegmentedToggle from "@/components/SegmentedToggle";
import MigrationBanner, { ErrorBanner } from "@/components/MigrationBanner";
import { AreaTrend, Bars, Donut } from "@/components/charts/Charts";
import { C } from "@/components/charts/theme";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const PERIODS = [
  { value: "7", label: "7d" },
  { value: "30", label: "30d" },
  { value: "90", label: "90d" },
];

export default async function GrowthPage({
  searchParams,
}: {
  searchParams: { days?: string };
}) {
  const days = Math.min(365, Math.max(7, Number(searchParams.days) || 30));

  const [signupsR, sourceR, cityR, platR, activR, cohortR, funnelR] = await Promise.all([
    safe(() => getDailySignups(days)),
    safe(() => getSignupsBySource(days)),
    safe(() => getSignupsByCity(days)),
    safe(getPlatformSplit),
    safe(() => getActivationRate(days, 7)),
    safe(() => getCohortRetention(8)),
    safe(getProductFunnel),
  ]);

  const migrationMissing = signupsR.migrationMissing;
  const totalInPeriod = signupsR.data?.reduce((a, b) => a + b.signups, 0) ?? 0;
  const activ = activR.data;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Growth &amp; Acquisition</h1>
          <p className="subtitle">
            Who&apos;s coming in, where from, and whether they stick. Use this to
            judge campaigns.
          </p>
        </div>
        <SegmentedToggle param="days" options={PERIODS} defaultValue="30" />
      </div>

      {migrationMissing ? <MigrationBanner /> : null}
      {signupsR.error ? <ErrorBanner message={signupsR.error} /> : null}

      <div className="kpis">
        <KpiCard
          label={`New users (${days}d)`}
          value={totalInPeriod}
          spark={signupsR.data ? { data: signupsR.data, dataKey: "signups" } : undefined}
          accent
        />
        <KpiCard
          label="Activation rate"
          value={activ ? `${activ.rate}%` : "—"}
          hint={activ ? `${activ.activated}/${activ.signups} acted in 7d` : undefined}
          sparkColor={C.green}
        />
        <KpiCard
          label="Activated users"
          value={activ?.activated ?? 0}
          hint="logged ≥1 activity"
        />
        <KpiCard
          label="Cumulative users"
          value={signupsR.data?.length ? signupsR.data[signupsR.data.length - 1].cumulative : 0}
        />
      </div>

      <div className="panels">
        <Panel
          title="New users per day"
          subtitle={`Last ${days} days — watch for lift after a campaign launch`}
          span={2}
        >
          {signupsR.data ? <AreaTrend data={signupsR.data} dataKey="signups" height={260} /> : <Empty />}
        </Panel>

        <Panel title="Cumulative users" subtitle="Total registered over time" span={2}>
          {signupsR.data ? (
            <AreaTrend data={signupsR.data} dataKey="cumulative" color={C.green} height={220} />
          ) : (
            <Empty />
          )}
        </Panel>

        <Panel title="Acquisition source" subtitle={`Where new users came from (${days}d)`} span={1}>
          {sourceR.data ? <Donut data={sourceR.data} /> : <Empty />}
        </Panel>

        <Panel title="Platform" subtitle="iOS vs Android (registered devices)" span={1}>
          {platR.data ? <Donut data={platR.data} /> : <Empty />}
        </Panel>

        <Panel title="New users by city" subtitle={`Top cities (${days}d)`} span={2}>
          {cityR.data ? <Bars data={cityR.data} horizontal height={Math.max(220, (cityR.data.length || 1) * 30)} perCategoryColor={false} /> : <Empty />}
        </Panel>

        <Panel
          title="Weekly retention"
          subtitle="% of each signup-cohort still active each week — real users stay green"
          span={2}
        >
          {cohortR.data ? <CohortHeatmap rows={cohortR.data} /> : <Empty />}
        </Panel>

        <Panel title="Product funnel" subtitle="Signup → activity → contact → salvation" span={2}>
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
      </div>

      <p className="muted" style={{ fontSize: 12, marginTop: 4 }}>
        Tip: tag your campaign links so new users carry a <code>signup_source</code> — then
        the &ldquo;Acquisition source&rdquo; chart breaks growth down per campaign.
      </p>
    </>
  );
}

function Empty() {
  return <div className="empty">No data yet.</div>;
}
