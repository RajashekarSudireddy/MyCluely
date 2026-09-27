import SectionHead from "./SectionHead";

const steps = [
  {
    number: "01",
    title: "Download and launch",
    description:
      "Install MyCluely on your Mac. It sits quietly in your menu bar as a 2.3 MB native app — no heavy runtimes, no bloat.",
  },
  {
    number: "02",
    title: "Connect your Gemini key",
    description:
      "Click the gear icon on the floating HUD and paste your free Google Gemini API key. MyCluely connects over WebSocket instantly.",
  },
  {
    number: "03",
    title: "Choose an audio source",
    description:
      "Select Microphone for voice Q&A, System Audio for meetings and lectures, or System + Mic for both sides of a conversation.",
  },
  {
    number: "04",
    title: "Get instant answers",
    description:
      "MyCluely listens continuously, detects questions as they are spoken, and streams concise answers in real time onto your HUD.",
  },
];

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="section">
      <div className="wrap">
        <SectionHead
          index="02"
          label="How it works"
          title="Running in under 60 seconds"
          copy="No complex setup, no account creation flows, no server infrastructure. Download, paste your key, and start listening."
        />

        <div>
          {steps.map((step) => (
            <div
              key={step.number}
              className="grid grid-cols-[64px_minmax(0,1fr)] sm:grid-cols-[120px_minmax(0,1fr)] gap-4 items-baseline border-t border-hairline py-6"
            >
              <p className="rule-marker text-sm">{step.number}</p>
              <div>
                <h3 className="type-h2 mb-2">{step.title}</h3>
                <p className="type-body text-muted max-w-2xl">
                  {step.description}
                </p>
              </div>
            </div>
          ))}
          <div className="border-t border-hairline" aria-hidden="true" />
        </div>
      </div>
    </section>
  );
}
