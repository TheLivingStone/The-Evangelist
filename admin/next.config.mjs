import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

// ---------------------------------------------------------------------------
// Load secrets from the repo-root .env so we don't duplicate the Supabase
// service-role key into admin/.env.local. admin/.env.local still wins for
// anything it defines (URL, admin password, session secret); we only fill in
// keys that are still missing from the root file.
//
// The root .env is NOT a clean dotenv file (it has free-text lines like
// "Project URL: ..."), so we parse only well-formed KEY=VALUE lines and pull
// the two server secrets we care about.
// ---------------------------------------------------------------------------
const ROOT_KEYS = ["SUPABASE_SERVICE_ROLE_KEY", "CLERK_SECRET_KEY"];

try {
  const here = dirname(fileURLToPath(import.meta.url));
  const rootEnvPath = join(here, "..", ".env");
  const text = readFileSync(rootEnvPath, "utf8");
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    if (!ROOT_KEYS.includes(key)) continue;
    if (process.env[key]) continue; // local/.env.local already set it — keep that
    let val = line.slice(eq + 1).trim();
    // strip surrounding quotes if present
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (val) process.env[key] = val;
  }
} catch {
  // No root .env (e.g. on a deployed host) — that's fine; env vars come from
  // the platform / admin/.env.local instead.
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // We render post photos with plain <img> tags (NOT next/image), so the
  // Next.js Image Optimization endpoint is never used. This deliberately
  // avoids the optimizer's remotePatterns DoS surface (GHSA-9g9p-9gw9-jx7f,
  // which has no 14.x patch). Do not switch these to next/image without
  // also upgrading Next and re-reviewing that advisory.
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
