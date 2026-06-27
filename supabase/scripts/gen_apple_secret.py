#!/usr/bin/env python3
"""Generate the Apple "client secret" JWT for Supabase's Apple auth provider.

Sign in with Apple does not take your .p8 key directly — Supabase needs a JWT
signed with it (ES256). That JWT expires (Apple allows max 6 months), so you
re-run this script and paste a fresh value whenever it lapses.

The private key is read from the .p8 FILE at runtime — it is never printed,
embedded, or committed. Only the resulting JWT is printed.

Usage:
    python3 supabase/scripts/gen_apple_secret.py \
        --p8 ~/Downloads/AuthKey_W24TPWR75W.p8 \
        --key-id W24TPWR75W \
        --team-id H98HSZ7HSS \
        --services-id com.theevangelist.auth

Then copy the printed JWT into Supabase → Authentication → Providers → Apple →
"Secret Key (for OAuth)".
"""
import argparse
import datetime
import sys

try:
    import jwt  # PyJWT
except ImportError:
    sys.exit("PyJWT not installed. Run: python3 -m pip install pyjwt cryptography")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--p8", required=True, help="path to AuthKey_XXXX.p8")
    ap.add_argument("--key-id", required=True, help="the Key ID (10 chars)")
    ap.add_argument("--team-id", required=True, help="your Apple Team ID (10 chars)")
    ap.add_argument(
        "--services-id",
        required=True,
        help="your Services ID (the 'sub'/'client_id', e.g. com.theevangelist.auth)",
    )
    ap.add_argument(
        "--months",
        type=int,
        default=6,
        help="validity in months (Apple max 6; default 6)",
    )
    args = ap.parse_args()

    with open(args.p8, "r") as f:
        private_key = f.read()

    now = datetime.datetime.now(datetime.timezone.utc)
    exp = now + datetime.timedelta(days=30 * args.months)

    token = jwt.encode(
        {
            "iss": args.team_id,
            "iat": int(now.timestamp()),
            "exp": int(exp.timestamp()),
            "aud": "https://appleid.apple.com",
            "sub": args.services_id,
        },
        private_key,
        algorithm="ES256",
        headers={"kid": args.key_id, "alg": "ES256"},
    )

    print(token)
    print(
        f"\n# ^ Apple client secret. Valid until {exp.date()} "
        f"(re-run before then). Paste into Supabase → Apple → Secret Key.",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
