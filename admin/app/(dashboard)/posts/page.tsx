import { getPosts } from "@/lib/data";
import { fmtDate, truncate } from "@/lib/format";
import { deletePost } from "@/app/actions";

export const dynamic = "force-dynamic";

export default async function PostsPage() {
  const posts = await getPosts();
  return (
    <>
      <h1>Posts</h1>
      <p className="subtitle">
        {posts.length} most recent community posts. Deleting removes a post for
        everyone — use for moderation.
      </p>

      <div className="tablewrap">
        {posts.length === 0 ? (
          <div className="empty">No posts yet.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Author</th>
                <th>Type</th>
                <th>Post</th>
                <th>Photo</th>
                <th>When</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {posts.map((p) => (
                <tr key={p.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>
                      {p.profiles?.full_name || "Evangelist"}
                    </div>
                    {p.profiles?.church ? (
                      <div className="muted" style={{ fontSize: 12 }}>
                        {p.profiles.church}
                      </div>
                    ) : null}
                  </td>
                  <td>
                    <span className="badge">{p.type}</span>
                  </td>
                  <td className="bodycell">{truncate(p.body)}</td>
                  <td>
                    {p.photo_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.photo_url} alt="" className="thumb" />
                    ) : (
                      <span className="muted">—</span>
                    )}
                  </td>
                  <td className="muted">{fmtDate(p.created_at)}</td>
                  <td>
                    <form action={deletePost}>
                      <input type="hidden" name="id" value={p.id} />
                      <button type="submit" className="btn danger">
                        Delete
                      </button>
                    </form>
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
