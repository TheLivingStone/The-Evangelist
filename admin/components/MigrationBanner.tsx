// Shown when the analytics RPCs aren't deployed yet. Tells the owner exactly
// how to turn the page on, instead of showing a crash.

export default function MigrationBanner() {
  return (
    <div className="banner">
      <strong>Analytics not turned on yet.</strong> This page runs on database
      rollups that haven&apos;t been deployed. Open the Supabase SQL Editor for
      project <code>ryufvbhddsntcrvpkpet</code> and run{" "}
      <code>supabase/migrate_admin_analytics.sql</code>. Refresh and it&apos;ll
      light up.
    </div>
  );
}

export function ErrorBanner({ message }: { message: string }) {
  return (
    <div className="banner banner-error">
      <strong>Couldn&apos;t load data.</strong> {message}
    </div>
  );
}
