import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Go and Tell — Admin",
  description: "Internal admin dashboard. Owners only.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
