import { getUsers } from "@/lib/data";
import { safe, getSignupsByCity, getPlatformSplit } from "@/lib/analytics";
import KpiCard from "@/components/KpiCard";
import Panel from "@/components/Panel";
import UsersTable from "./UsersTable";
import { Bars, Donut } from "@/components/charts/Charts";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function UsersPage() {
  const [users, cityR, platR] = await Promise.all([
    getUsers(500),
    safe(() => getSignupsByCity(3650, 12)), // all-time top cities
    safe(getPlatformSplit),
  ]);

  const active = users.filter(
    (u) => u.total_conversations + u.total_salvations + u.total_followups > 0,
  ).length;
  const onStreak = users.filter((u) => u.current_streak > 0).length;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Users</h1>
          <p className="subtitle">
            {users.length} most recent profiles · search &amp; filter below.
          </p>
        </div>
      </div>

      <div className="kpis">
        <KpiCard label="Loaded users" value={users.length} accent />
        <KpiCard label="With activity" value={active} hint={`${users.length - active} dormant`} />
        <KpiCard label="On a streak" value={onStreak} />
      </div>

      <div className="panels">
        <Panel title="Users by city" subtitle="Top cities" span={1}>
          {cityR.data ? <Bars data={cityR.data} horizontal height={Math.max(200, (cityR.data.length || 1) * 28)} /> : <Empty />}
        </Panel>
        <Panel title="Platform" subtitle="Registered devices" span={1}>
          {platR.data ? <Donut data={platR.data} /> : <Empty />}
        </Panel>
      </div>

      <UsersTable users={users} />
    </>
  );
}

function Empty() {
  return <div className="empty">No data yet.</div>;
}
