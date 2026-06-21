import Nav from "./Nav";

// Shell for all authenticated pages: sidebar nav + logout. The /login page
// lives outside this route group, so it has no sidebar.
export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">
          The Evangelist<span className="dot">.</span>
        </div>
        <Nav />
        <form action="/api/logout" method="post">
          <button type="submit" className="logout">
            Log out
          </button>
        </form>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
