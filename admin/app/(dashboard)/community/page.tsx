import { getPosts } from "@/lib/data";
import {
  safe,
  getCommunityStats,
  getDailyPosts,
  getPostTypeMix,
  getReactionMix,
  getTopPosts,
} from "@/lib/analytics";
import { fmtDate, truncate } from "@/lib/format";
import KpiCard from "@/components/KpiCard";
import Panel from "@/components/Panel";
import MigrationBanner from "@/components/MigrationBanner";
import PostsTable from "./PostsTable";
import { StackedArea, Donut } from "@/components/charts/Charts";
import { C } from "@/components/charts/theme";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const POST_KEYS = ["testimony", "outreach", "prayer", "salvation", "update_"];

export default async function CommunityPage() {
  const [posts, statsR, dailyR, typeR, reactR, topR] = await Promise.all([
    getPosts(300),
    safe(getCommunityStats),
    safe(() => getDailyPosts(30)),
    safe(getPostTypeMix),
    safe(getReactionMix),
    safe(() => getTopPosts(8)),
  ]);

  const s = statsR.data;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Community</h1>
          <p className="subtitle">
            Feed health, engagement, and moderation in one place.
          </p>
        </div>
      </div>

      {statsR.migrationMissing ? <MigrationBanner /> : null}

      {s ? (
        <div className="kpis">
          <KpiCard label="Total posts" value={s.total_posts} accent />
          <KpiCard label="Posts (7d)" value={s.posts_7d} />
          <KpiCard label="Reactions" value={s.total_reactions} sparkColor={C.green} />
          <KpiCard label="Comments" value={s.total_comments} />
          <KpiCard label="Avg reactions / post" value={s.avg_reactions} />
          <KpiCard label="Avg comments / post" value={s.avg_comments} />
        </div>
      ) : null}

      <div className="panels">
        <Panel title="Posts over time" subtitle="Last 30 days, by type" span={2}>
          {dailyR.data ? <StackedArea data={dailyR.data} keys={POST_KEYS} /> : <Empty />}
        </Panel>

        <Panel title="Post type mix" subtitle="All-time" span={1}>
          {typeR.data ? <Donut data={typeR.data} /> : <Empty />}
        </Panel>

        <Panel title="Reaction sentiment" subtitle="How the community responds" span={1}>
          {reactR.data ? <Donut data={reactR.data} /> : <Empty />}
        </Panel>

        <Panel title="Top posts" subtitle="By reactions + comments" span={2}>
          {topR.data && topR.data.length ? (
            <div className="tablewrap" style={{ border: "none" }}>
              <table>
                <thead>
                  <tr>
                    <th>Post</th>
                    <th>Author</th>
                    <th>Type</th>
                    <th>❤️</th>
                    <th>💬</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  {topR.data.map((p) => (
                    <tr key={p.id}>
                      <td className="bodycell">{truncate(p.body, 90)}</td>
                      <td>{p.author}</td>
                      <td>
                        <span className="badge">{p.type}</span>
                      </td>
                      <td style={{ color: C.accent2, fontWeight: 700 }}>{p.reactions}</td>
                      <td style={{ fontWeight: 700 }}>{p.comments}</td>
                      <td className="muted">{fmtDate(p.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <Empty />
          )}
        </Panel>
      </div>

      <h2 style={{ fontSize: 16, margin: "26px 0 14px" }}>Moderation</h2>
      <PostsTable posts={posts} />
    </>
  );
}

function Empty() {
  return <div className="empty">No data yet.</div>;
}
