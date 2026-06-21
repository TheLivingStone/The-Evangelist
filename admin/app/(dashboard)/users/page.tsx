import { getUsers } from "@/lib/data";
import { fmtDate } from "@/lib/format";

export const dynamic = "force-dynamic";

export default async function UsersPage() {
  const users = await getUsers();
  return (
    <>
      <h1>Users</h1>
      <p className="subtitle">
        {users.length} most recent profiles. Stats are each user&apos;s lifetime
        totals.
      </p>

      <div className="tablewrap">
        {users.length === 0 ? (
          <div className="empty">No users yet.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>City</th>
                <th>Church</th>
                <th>Streak</th>
                <th>Convos</th>
                <th>Salvations</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>{u.full_name}</div>
                    {u.username ? (
                      <div className="muted" style={{ fontSize: 12 }}>
                        @{u.username}
                      </div>
                    ) : null}
                  </td>
                  <td className="muted">{u.city || "—"}</td>
                  <td className="muted">{u.church || "—"}</td>
                  <td>
                    {u.current_streak}
                    <span className="muted"> / {u.longest_streak}</span>
                  </td>
                  <td>{u.total_conversations}</td>
                  <td>{u.total_salvations}</td>
                  <td className="muted">{fmtDate(u.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
