import {
  safe,
  getKpiOverview,
  getDailyActivity,
  getActivityMix,
  getLeaderboard,
  getStreakDistribution,
  getAchievementDistribution,
  getContactFunnel,
} from "@/lib/analytics";
import Panel from "@/components/Panel";
import Funnel from "@/components/Funnel";
import Leaderboard from "@/components/Leaderboard";
import SegmentedToggle from "@/components/SegmentedToggle";
import MigrationBanner, { ErrorBanner } from "@/components/MigrationBanner";
import { StackedArea, Donut, Bars } from "@/components/charts/Charts";
import { C, prettyLabel } from "@/components/charts/theme";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const ACTIVITY_KEYS = ["conversation", "salvation", "prayer", "followup", "church_connection"];
const STATUS_LABEL: Record<string, string> = {
  new_contact: "New contact",
  accepted_christ: "Accepted Christ",
  followup_started: "Follow-up started",
  connected_to_church: "Connected to church",
  active: "Active disciple",
};
const METRICS = [
  { value: "salvations", label: "Salvations" },
  { value: "conversations", label: "Conversations" },
  { value: "followups", label: "Follow-ups" },
  { value: "streak", label: "Streak" },
];
const METRIC_UNIT: Record<string, string> = {
  salvations: "saved",
  conversations: "talks",
  followups: "f/u",
  streak: "days",
};

export default async function ImpactPage({
  searchParams,
}: {
  searchParams: { metric?: string };
}) {
  const metric = METRICS.some((m) => m.value === searchParams.metric)
    ? (searchParams.metric as string)
    : "salvations";

  const [kpiR, actR, mixR, leadR, streakR, achR, cfR] = await Promise.all([
    safe(getKpiOverview),
    safe(() => getDailyActivity(30)),
    safe(getActivityMix),
    safe(() => getLeaderboard(metric, 10)),
    safe(getStreakDistribution),
    safe(getAchievementDistribution),
    safe(getContactFunnel),
  ]);

  const migrationMissing = kpiR.migrationMissing;
  const k = kpiR.data;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Kingdom Impact</h1>
          <p className="subtitle">The fruit of the mission, measured.</p>
        </div>
      </div>

      {migrationMissing ? <MigrationBanner /> : null}
      {kpiR.error ? <ErrorBanner message={kpiR.error} /> : null}

      {k ? (
        <div className="panels">
          <Panel span={2} title="The numbers that matter">
            <div className="bignums">
              <Big n={k.total_salvations} l="Salvations" color={C.green} />
              <Big n={k.total_conversations} l="Conversations" color={C.accent} />
              <Big n={k.total_prayers} l="Prayers" color={C.blue} />
              <Big
                n={k.total_conversations > 0 ? Math.round((k.total_salvations / k.total_conversations) * 100) : 0}
                l="Conversion %"
                color={C.purple}
                suffix="%"
              />
            </div>
          </Panel>
        </div>
      ) : null}

      <div className="panels">
        <Panel title="Activity over time" subtitle="Last 30 days, by type" span={2}>
          {actR.data ? <StackedArea data={actR.data} keys={ACTIVITY_KEYS} /> : <Empty />}
        </Panel>

        <Panel
          title="Leaderboard"
          subtitle="Top evangelists"
          span={1}
          right={<SegmentedToggle param="metric" options={METRICS} defaultValue="salvations" />}
        >
          {leadR.data ? <Leaderboard rows={leadR.data} unit={METRIC_UNIT[metric]} /> : <Empty />}
        </Panel>

        <Panel title="Activity mix" subtitle="All-time share" span={1}>
          {mixR.data ? <Donut data={mixR.data} /> : <Empty />}
        </Panel>

        <Panel title="Contact journey" subtitle="People being discipled, by stage" span={1}>
          {cfR.data ? (
            <Funnel
              colors={[C.muted, C.green, C.accent, C.blue, C.purple]}
              steps={cfR.data
                .sort((a, b) => a.step_order - b.step_order)
                .map((s) => ({ label: STATUS_LABEL[s.status] || prettyLabel(s.status), value: s.contacts }))}
            />
          ) : (
            <Empty />
          )}
        </Panel>

        <Panel title="Streak distribution" subtitle="How many users are on a streak" span={1}>
          {streakR.data ? (
            <Bars
              data={streakR.data.map((s) => ({ name: s.bucket, value: s.users }))}
              color={C.accent}
              height={240}
            />
          ) : (
            <Empty />
          )}
        </Panel>

        <Panel title="Achievements unlocked" subtitle="Which badges are common vs rare" span={2}>
          {achR.data ? (
            <Bars
              data={achR.data.map((a) => ({ name: `${a.icon} ${a.name}`, value: a.unlocks }))}
              horizontal
              color={C.accent2}
              height={Math.max(220, achR.data.length * 36)}
            />
          ) : (
            <Empty />
          )}
        </Panel>
      </div>
    </>
  );
}

function Big({ n, l, color, suffix }: { n: number; l: string; color: string; suffix?: string }) {
  return (
    <div className="bignum">
      <div className="n" style={{ color }}>
        {n.toLocaleString()}
        {suffix ?? ""}
      </div>
      <div className="l">{l}</div>
    </div>
  );
}

function Empty() {
  return <div className="empty">No data yet.</div>;
}
