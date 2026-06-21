"use client";

import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get("next") || "/";
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const res = await fetch("/api/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
      });
      if (res.ok) {
        router.replace(next);
        router.refresh();
      } else {
        const data = await res.json().catch(() => ({}));
        setError(data.error || "Login failed.");
        setBusy(false);
      }
    } catch {
      setError("Network error. Try again.");
      setBusy(false);
    }
  }

  return (
    <form className="login-card" onSubmit={submit}>
      <h1>
        The Evangelist<span style={{ color: "var(--accent)" }}>.</span>
      </h1>
      <p className="muted" style={{ margin: 0 }}>
        Admin access
      </p>
      <input
        type="password"
        placeholder="Admin password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        autoFocus
        autoComplete="current-password"
      />
      <button type="submit" disabled={busy || !password}>
        {busy ? "Checking…" : "Enter dashboard"}
      </button>
      <div className="error">{error}</div>
    </form>
  );
}

export default function LoginPage() {
  return (
    <div className="login-wrap">
      <Suspense fallback={<div className="login-card">Loading…</div>}>
        <LoginForm />
      </Suspense>
    </div>
  );
}
