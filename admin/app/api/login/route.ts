import { NextRequest, NextResponse } from "next/server";
import { createSessionToken, sessionCookie } from "@/lib/session";

// POST { password } → if it matches ADMIN_PASSWORD, set the signed session
// cookie. Runs on the Node runtime (default), so process.env is available.
export async function POST(req: NextRequest) {
  const expected = process.env.ADMIN_PASSWORD;
  if (!expected) {
    return NextResponse.json(
      { error: "Server is misconfigured: ADMIN_PASSWORD is not set." },
      { status: 500 },
    );
  }

  let password = "";
  try {
    const body = await req.json();
    password = typeof body?.password === "string" ? body.password : "";
  } catch {
    // fall through to the generic error below
  }

  if (!password || password !== expected) {
    return NextResponse.json({ error: "Incorrect password." }, { status: 401 });
  }

  const token = await createSessionToken();
  const res = NextResponse.json({ ok: true });
  res.cookies.set(sessionCookie.name, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: sessionCookie.maxAge,
  });
  return res;
}
