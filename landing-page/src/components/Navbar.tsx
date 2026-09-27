"use client";

import { useState, useEffect } from "react";

const navLinks = [
  { label: "Features", href: "#features" },
  { label: "How It Works", href: "#how-it-works" },
  { label: "Architecture", href: "#architecture" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    handleScroll();
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <nav
      className={`fixed top-0 left-0 right-0 z-50 bg-ink transition-colors ${
        scrolled ? "border-b border-hairline" : "border-b border-transparent"
      }`}
    >
      <div className="wrap">
        <div className="flex items-center justify-between h-16 sm:h-20">
          {/* Logo */}
          <a href="#" className="flex items-center gap-3" aria-label="MyCluely home">
            <span className="flex items-center justify-center w-8 h-8 rounded-lg bg-accent">
              <span className="text-ink font-bold text-sm leading-none">M</span>
            </span>
            <span className="text-lg font-bold text-paper tracking-tight">
              MyCluely
            </span>
          </a>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-1">
            {navLinks.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className="px-3 lg:px-4 py-2 text-sm text-muted hover:text-paper transition-colors"
              >
                {link.label}
              </a>
            ))}
          </div>

          {/* CTA */}
          <div className="hidden md:flex items-center">
            <a href="#pricing" className="btn btn-primary">
              Download Free
            </a>
          </div>

          {/* Mobile menu button */}
          <button
            onClick={() => setMobileOpen(!mobileOpen)}
            className="md:hidden p-2 text-muted hover:text-paper transition-colors"
            aria-label="Toggle menu"
            aria-expanded={mobileOpen}
          >
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              {mobileOpen ? (
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M6 18L18 6M6 6l12 12" />
              ) : (
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 6h16M4 12h16M4 18h16" />
              )}
            </svg>
          </button>
        </div>

        {/* Mobile Menu */}
        {mobileOpen && (
          <div className="md:hidden pb-4 border-t border-hairline">
            <div className="flex flex-col gap-1 pt-3">
              {navLinks.map((link) => (
                <a
                  key={link.href}
                  href={link.href}
                  onClick={() => setMobileOpen(false)}
                  className="px-2 py-2.5 text-sm text-muted hover:text-paper transition-colors"
                >
                  {link.label}
                </a>
              ))}
              <a
                href="#pricing"
                onClick={() => setMobileOpen(false)}
                className="btn btn-primary mt-2 w-full"
              >
                Download Free
              </a>
            </div>
          </div>
        )}
      </div>
    </nav>
  );
}
