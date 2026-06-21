import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "The Evangelist — Admin",
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
