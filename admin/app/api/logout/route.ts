import { NextResponse } from "next/server";
import { sessionCookie } from "@/lib/session";

// Clears the admin session cookie and returns to the login page.
export async function POST() {
  const res = NextResponse.redirect(
    new URL("/login", process.env.ADMIN_BASE_URL ?? "http://localhost:3100"),
    { status: 303 },
  );
  res.cookies.set(sessionCookie.name, "", {
    httpOnly: true,
    path: "/",
    maxAge: 0,
  });
  return res;
}
