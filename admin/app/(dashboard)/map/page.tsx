import {
  safe,
  getGeoActivity,
  getGeoChurches,
  getGeoLive,
  getGeoPosts,
  getCityRollup,
} from "@/lib/analytics";
import Panel from "@/components/Panel";
import MigrationBanner, { ErrorBanner } from "@/components/MigrationBanner";
import MapClient from "./MapClient";
import { C } from "@/components/charts/theme";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function MapPage() {
  const [actR, chR, liveR, postsR, cityR] = await Promise.all([
    safe(() => getGeoActivity(30, 2000)),
    safe(getGeoChurches),
    safe(getGeoLive),
    safe(() => getGeoPosts(30, 500)),
    safe(() => getCityRollup(25)),
  ]);

  const migrationMissing = actR.migrationMissing;
  const hasAnyGeo =
    (actR.data?.length || 0) +
      (chR.data?.length || 0) +
      (liveR.data?.length || 0) +
      (postsR.data?.length || 0) >
    0;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Map</h1>
          <p className="subtitle">
            Where the mission is happening — activity heatmap, churches, and live
            evangelists.
          </p>
        </div>
      </div>

      {migrationMissing ? <MigrationBanner /> : null}
      {actR.error ? <ErrorBanner message={actR.error} /> : null}

      {!migrationMissing && !hasAnyGeo ? (
        <div className="banner">
          No located data yet. As users run outreach sessions, register churches,
          and post with location on, points will appear here.
        </div>
      ) : null}

      {!migrationMissing ? (
        <MapClient
          activity={actR.data ?? []}
          churches={chR.data ?? []}
          live={liveR.data ?? []}
          posts={postsR.data ?? []}
        />
      ) : null}

      <div className="panels" style={{ marginTop: 16 }}>
        <Panel title="By city" subtitle="Users, salvations & churches per city" span={2}>
          {cityR.data && cityR.data.length ? (
            <div className="tablewrap" style={{ border: "none" }}>
              <table>
                <thead>
                  <tr>
                    <th>City</th>
                    <th>Users</th>
                    <th>Salvations</th>
                    <th>Conversations</th>
                    <th>Churches</th>
                  </tr>
                </thead>
                <tbody>
                  {cityR.data.map((c) => (
                    <tr key={c.city}>
                      <td style={{ fontWeight: 600 }}>{c.city}</td>
                      <td>{c.users.toLocaleString()}</td>
                      <td style={{ color: C.green }}>{c.salvations.toLocaleString()}</td>
                      <td>{c.conversations.toLocaleString()}</td>
                      <td>{c.churches.toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="empty">No city data yet.</div>
          )}
        </Panel>
      </div>
    </>
  );
}
