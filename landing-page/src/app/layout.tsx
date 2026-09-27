import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./globals.css";

const inter = localFont({
  src: "./fonts/Inter-Variable.woff2",
  variable: "--font-inter",
  weight: "100 900",
  display: "swap",
});

const robotoMono = localFont({
  src: "./fonts/RobotoMono-Variable.woff2",
  variable: "--font-roboto-mono",
  weight: "100 700",
  display: "swap",
});

export const metadata: Metadata = {
  title: "MyCluely — Real-Time AI Speech Assistant for macOS",
  description:
    "Ultra-lightweight native macOS floating HUD for real-time speech monitoring and instantaneous AI question answering. Powered by Gemini Live API.",
  keywords: [
    "AI assistant",
    "speech recognition",
    "macOS",
    "real-time",
    "Gemini",
    "meeting assistant",
    "question answering",
  ],
  openGraph: {
    title: "MyCluely — Real-Time AI Speech Assistant for macOS",
    description:
      "Ultra-lightweight native macOS floating HUD for real-time speech monitoring and instantaneous AI question answering.",
    type: "website",
  },
};

export const viewport: Viewport = {
  themeColor: "#020202",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${inter.variable} ${robotoMono.variable} font-sans antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
