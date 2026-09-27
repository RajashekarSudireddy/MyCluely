import SectionHead from "./SectionHead";

const features = [
  {
    index: "01",
    title: "24/7 live cloud streaming",
    description:
      "Streams raw 16kHz PCM audio directly to Gemini Live via WebSockets. Sub-second answers flow token-by-token onto the HUD — no local transcription bottleneck.",
  },
  {
    index: "02",
    title: "Mic + system audio capture",
    description:
      "Capture microphone audio, internal system audio (Zoom, Google Meet, YouTube), or both simultaneously. No virtual audio drivers — pure native ScreenCaptureKit.",
  },
  {
    index: "03",
    title: "Floating HUD",
    description:
      "An always-on-top panel visible across all macOS spaces and full-screen apps. Dynamic auto-resizing, drag-anywhere placement, and ultra-compact pill mode.",
  },
  {
    index: "04",
    title: "Dual intelligence engines",
    description:
      "Primary: Gemini Live WebSocket for maximum speed. Fallback: Apple speech recognition with Gemini REST. Automatic failover keeps answers uninterrupted.",
  },
  {
    index: "05",
    title: "Secure authentication",
    description:
      "Email and password login with PBKDF2 password hashing and macOS Keychain storage, plus Google OAuth 2.0 PKCE. Microphones and AI stay locked until authenticated.",
  },
  {
    index: "06",
    title: "Ultra-lightweight",
    description:
      "Pure Swift 6 with AppKit and SwiftUI. A 2.3 MB binary using ~25 MB of RAM. Zero Electron, zero webviews — native performance that never slows your Mac.",
  },
  {
    index: "07",
    title: "Productivity shortcuts",
    description:
      "Global hotkeys (⌘⇧P to pause, ⌘⇧H to toggle the HUD), one-click copy of answers to the clipboard, and a session history drawer for past Q&As.",
  },
  {
    index: "08",
    title: "In-panel settings",
    description:
      "No detached popover windows. Click the gear icon and the HUD flips into a native settings card — API key, audio source, and engine in one place.",
  },
];

export default function Features() {
  return (
    <section id="features" className="section">
      <div className="wrap">
        <SectionHead
          index="01"
          label="Features"
          title="Never miss an answer"
          copy="Built with native Apple frameworks and Google Gemini for the fastest, most lightweight assistant experience on macOS."
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {features.map((feature) => (
            <article key={feature.index} className="panel p-6">
              <p className="rule-marker mb-4">{feature.index}</p>
              <h3 className="type-h2 mb-2">{feature.title}</h3>
              <p className="text-sm text-muted leading-relaxed">
                {feature.description}
              </p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
