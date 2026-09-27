"use client";

import { useState } from "react";
import SectionHead from "./SectionHead";

const faqs = [
  {
    question: "Do I need a Gemini API key?",
    answer:
      "Yes — on the Free plan, you bring your own Google Gemini API key (available for free at Google AI Studio). On Pro and Team plans, we provide a managed key so you don't need to worry about it.",
  },
  {
    question: "Which macOS versions are supported?",
    answer:
      "MyCluely requires macOS 14.0 (Sonoma) or newer. It uses native Apple frameworks like ScreenCaptureKit and AVAudioEngine that are available on modern macOS versions.",
  },
  {
    question: "How does System Audio capture work?",
    answer:
      "MyCluely uses Apple's native ScreenCaptureKit to tap into system-wide audio output. This captures audio from Zoom, Google Meet, YouTube, Spotify, and any other app — no virtual audio drivers like BlackHole or Soundflower needed.",
  },
  {
    question: "Is my audio data sent to the cloud?",
    answer:
      "In the default 24/7 Cloud Live mode, raw audio is streamed over an encrypted WebSocket to the selected Gemini Live or OpenAI Realtime provider for processing. That provider's terms apply. In Local STT mode, transcription requires on-device Apple Speech support, and detected question text is sent to Gemini's REST API.",
  },
  {
    question: "How is the app so small (2.3 MB)?",
    answer:
      "MyCluely is built entirely in Swift 6 using native Apple frameworks (AppKit, SwiftUI, AVFoundation, ScreenCaptureKit). There's no Electron, no embedded browser engine, no heavy runtimes — just compiled native code that interfaces directly with macOS system APIs.",
  },
  {
    question: "Can I use MyCluely during Zoom / Google Meet calls?",
    answer:
      "Absolutely. Select 'System Audio' or 'System + Mic' to capture meeting audio. MyCluely's floating HUD stays on top of full-screen apps, so you can see AI answers while in your meeting without switching windows.",
  },
  {
    question: "What happens if my internet connection drops?",
    answer:
      "MyCluely has built-in 24/7 resilience. If the WebSocket connection drops, it automatically reconnects with exponential backoff (1.5s to 8.0s). It also handles Gemini's server-side session rotation (goAway signals) seamlessly.",
  },
  {
    question: "Is there a Windows or Linux version?",
    answer:
      "MyCluely is currently macOS-only, built with native Apple frameworks. Windows and Linux versions are on the roadmap.",
  },
];

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  return (
    <section id="faq" className="section">
      <div className="wrap">
        <SectionHead index="05" label="FAQ" title="Questions, answered" />

        <div>
          {faqs.map((faq, index) => {
            const open = openIndex === index;
            return (
              <div key={faq.question} className="border-t border-hairline">
                <button
                  onClick={() => setOpenIndex(open ? null : index)}
                  className="w-full grid grid-cols-[48px_minmax(0,1fr)_24px] items-baseline gap-4 py-5 text-left"
                  aria-expanded={open}
                >
                  <span className="label">
                    {String(index + 1).padStart(2, "0")}
                  </span>
                  <span className="text-base font-medium text-paper">
                    {faq.question}
                  </span>
                  <span
                    className="font-mono text-lg leading-none text-structural text-right"
                    aria-hidden="true"
                  >
                    {open ? "−" : "+"}
                  </span>
                </button>
                <div
                  className={`grid transition-all duration-200 ${
                    open
                      ? "grid-rows-[1fr] opacity-100"
                      : "grid-rows-[0fr] opacity-0"
                  }`}
                >
                  <div className="overflow-hidden">
                    <p className="text-sm text-muted leading-relaxed pb-5 pl-16 pr-10 max-w-3xl">
                      {faq.answer}
                    </p>
                  </div>
                </div>
              </div>
            );
          })}
          <div className="border-t border-hairline" aria-hidden="true" />
        </div>
      </div>
    </section>
  );
}
