import { NextRequest, NextResponse } from "next/server";
import { sessionCookie, verifySessionToken } from "./lib/session";

// Gate every page/route behind a valid admin session, EXCEPT the login page
// and the login API (otherwise you could never get in). Static assets are
// excluded via the matcher below.
const PUBLIC_PATHS = ["/login", "/api/login"];

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  if (PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(p + "/"))) {
    return NextResponse.next();
  }

  const token = req.cookies.get(sessionCookie.name)?.value;
  const ok = await verifySessionToken(token);
  if (ok) return NextResponse.next();

  // Not authenticated → bounce to /login (remember where they were headed).
  const url = req.nextUrl.clone();
  url.pathname = "/login";
  url.search = pathname && pathname !== "/" ? `?next=${encodeURIComponent(pathname)}` : "";
  return NextResponse.redirect(url);
}

export const config = {
  // Run on everything except Next internals and the favicon.
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
