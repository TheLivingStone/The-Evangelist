"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";

// A segmented control that writes its value to a URL query param and triggers a
// server re-render (so the page's RPCs re-run with the new range). Used for the
// 7/30/90-day period toggles and the leaderboard metric switcher.

export default function SegmentedToggle({
  param,
  options,
  defaultValue,
}: {
  param: string;
  options: { value: string; label: string }[];
  defaultValue: string;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const sp = useSearchParams();
  const current = sp.get(param) ?? defaultValue;

  function set(value: string) {
    const next = new URLSearchParams(sp.toString());
    if (value === defaultValue) next.delete(param);
    else next.set(param, value);
    const qs = next.toString();
    router.push(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  }

  return (
    <div className="segmented">
      {options.map((o) => (
        <button
          key={o.value}
          className={o.value === current ? "seg active" : "seg"}
          onClick={() => set(o.value)}
          type="button"
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
