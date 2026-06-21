import "server-only";
import { cookies } from "next/headers";
import { sessionCookie, verifySessionToken } from "./session";

// Defense in depth: middleware already blocks unauthenticated page loads, but
// server actions and route handlers can be POSTed to directly, so re-verify
// the signed session cookie here before doing anything privileged.
export async function requireAdmin(): Promise<void> {
  const token = cookies().get(sessionCookie.name)?.value;
  const ok = await verifySessionToken(token);
  if (!ok) {
    throw new Error("Not authorized");
  }
}
