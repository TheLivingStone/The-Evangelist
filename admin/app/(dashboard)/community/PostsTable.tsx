"use client";

import FilterableTable from "@/components/FilterableTable";
import { deletePost } from "@/app/actions";
import { fmtDate, truncate } from "@/lib/format";
import type { PostRow } from "@/lib/data";

const TYPES = ["testimony", "outreach", "prayer", "salvation", "update"];

export default function PostsTable({ posts }: { posts: PostRow[] }) {
  const cities = Array.from(
    new Set(posts.map((p) => p.city).filter(Boolean) as string[]),
  ).sort();

  return (
    <FilterableTable<PostRow>
      rows={posts}
      columns={["Author", "Type", "Post", "Photo", "Date", ""]}
      searchKeys={(p) =>
        `${p.body} ${p.profiles?.full_name ?? ""} ${p.city ?? ""} ${p.type}`
      }
      filters={[
        {
          key: "type",
          label: "Types",
          options: TYPES.map((t) => ({ value: t, label: t })),
          match: (p, v) => p.type === v,
        },
        {
          key: "city",
          label: "Cities",
          options: cities.map((c) => ({ value: c, label: c })),
          match: (p, v) => p.city === v,
        },
      ]}
      renderRow={(p) => (
        <tr key={p.id}>
          <td>
            <div style={{ fontWeight: 600 }}>{p.profiles?.full_name ?? "—"}</div>
            {p.profiles?.church ? (
              <div className="muted" style={{ fontSize: 12 }}>
                {p.profiles.church}
              </div>
            ) : null}
          </td>
          <td>
            <span className="badge">{p.type}</span>
          </td>
          <td className="bodycell">{truncate(p.body, 140)}</td>
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
      )}
    />
  );
}
