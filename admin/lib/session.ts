// Admin session cookie: a tiny signed token proving "this browser entered the
// correct admin password". We sign with HMAC-SHA256 via the Web Crypto API so
// the SAME code verifies in both the Edge middleware and Node route handlers.
//
// The token is:  <expiryEpochMs>.<hexHmac(expiryEpochMs)>
// There is no per-user identity here — a single shared admin password gates
// access (per the chosen "separate admin login" model).

const COOKIE_NAME = "evangelist_admin";
const MAX_AGE_SECONDS = 60 * 60 * 12; // 12 hours

function encodeUtf8(s: string): ArrayBuffer {
  const u8 = new TextEncoder().encode(s);
  // Copy into a fresh, standalone ArrayBuffer so the type is exactly
  // ArrayBuffer (not ArrayBufferLike), satisfying BufferSource across both
  // the Edge and Node Web Crypto typings.
  const buf = new ArrayBuffer(u8.byteLength);
  new Uint8Array(buf).set(u8);
  return buf;
}

function secretKeyData(): ArrayBuffer {
  const secret = process.env.ADMIN_SESSION_SECRET;
  if (!secret) {
    throw new Error("ADMIN_SESSION_SECRET is not set");
  }
  return encodeUtf8(secret);
}

async function importKey(): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    secretKeyData(),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

function toHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function sign(payload: string): Promise<string> {
  const key = await importKey();
  const sig = await crypto.subtle.sign("HMAC", key, encodeUtf8(payload));
  return toHex(sig);
}

/** Build a fresh signed session token valid for MAX_AGE_SECONDS. */
export async function createSessionToken(): Promise<string> {
  const expiry = Date.now() + MAX_AGE_SECONDS * 1000;
  const payload = String(expiry);
  const mac = await sign(payload);
  return `${payload}.${mac}`;
}

/** Constant-time-ish verify: signature matches AND not expired. */
export async function verifySessionToken(
  token: string | undefined | null,
): Promise<boolean> {
  if (!token) return false;
  const dot = token.indexOf(".");
  if (dot < 0) return false;
  const payload = token.slice(0, dot);
  const mac = token.slice(dot + 1);
  const expected = await sign(payload);
  if (!timingSafeEqual(mac, expected)) return false;
  const expiry = Number(payload);
  if (!Number.isFinite(expiry) || Date.now() > expiry) return false;
  return true;
}

// Length-checked, constant-time string compare to avoid leaking via timing.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export const sessionCookie = {
  name: COOKIE_NAME,
  maxAge: MAX_AGE_SECONDS,
};
