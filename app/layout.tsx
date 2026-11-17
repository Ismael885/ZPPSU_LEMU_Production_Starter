import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ZPPSU LEMU | Licensure Examination Management Unit",
  description: "ZPPSU Licensure Examination Management Unit review and examination portal."
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
