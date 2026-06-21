"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/", label: "Overview" },
  { href: "/users", label: "Users" },
  { href: "/posts", label: "Posts" },
  { href: "/churches", label: "Churches" },
];

export default function Nav() {
  const pathname = usePathname();
  return (
    <>
      {LINKS.map((l) => {
        const active = l.href === "/" ? pathname === "/" : pathname.startsWith(l.href);
        return (
          <Link
            key={l.href}
            href={l.href}
            className={active ? "navlink active" : "navlink"}
          >
            {l.label}
          </Link>
        );
      })}
    </>
  );
}
