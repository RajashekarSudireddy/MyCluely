const eqHeights = [
  42, 68, 30, 55, 80, 48, 62, 35, 72, 50, 88, 44, 60, 28, 66, 52, 76, 40,
  58, 46,
];
const hotBarIndex = 10;

const metrics = [
  { label: "Binary", value: "2.3 MB" },
  { label: "Memory", value: "~25 MB" },
  { label: "Latency", value: "<100ms" },
  { label: "Uptime", value: "24/7" },
];

export default function Hero() {
  return (
    <section className="section">
      <div className="wrap pt-16 sm:pt-20">
        <div className="hero-grid">
          {/* Intro */}
          <div>
            <p className="kicker">Real-time AI speech assistant for macOS</p>
            <h1 className="type-display mt-4">
              Your AI ear for every conversation.
            </h1>
            <p className="lede mt-6">
              An ultra-lightweight native macOS HUD that listens to meetings,
              lectures, and podcasts — then streams instant answers the moment
              a question is asked. Just 2.3 MB.
            </p>
            <div className="flex flex-col sm:flex-row gap-3 mt-6">
              <a href="#pricing" className="btn btn-primary">
                <span className="flex items-center gap-2">
                  Download for macOS
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
                  </svg>
                </span>
              </a>
              <a href="#how-it-works" className="btn btn-secondary">
                See how it works
              </a>
            </div>
          </div>

          {/* HUD mockup */}
          <aside className="panel p-6" aria-label="MyCluely HUD preview">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <span className="flex items-center justify-center w-6 h-6 rounded-lg bg-accent">
                  <span className="text-ink text-xs font-bold leading-none">M</span>
                </span>
                <span className="text-paper text-sm font-semibold">MyCluely</span>
              </div>
              <span className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-lg bg-accent" aria-hidden="true" />
                <span className="label">Live</span>
              </span>
            </div>

            {/* Equalizer */}
            <div className="flex items-end gap-1 h-8 mb-4" aria-hidden="true">
              {eqHeights.map((height, i) => (
                <div
                  key={i}
                  className={`eq-bar flex-1 ${i === hotBarIndex ? "eq-bar-hot" : ""}`}
                  style={{ height: `${height}%` }}
                />
              ))}
            </div>

            {/* Transcript */}
            <div className="rounded-lg border border-hairline bg-coal p-3 mb-3">
              <p className="label mb-1">Transcript</p>
              <p className="text-sm text-paper leading-relaxed">
                &ldquo;…so what&apos;s the difference between TCP and UDP for
                real-time audio streaming?&rdquo;
              </p>
            </div>

            {/* Answer */}
            <div className="rounded-lg border border-hairline bg-coal p-3">
              <p className="label mb-1">Answer</p>
              <p className="text-sm text-muted leading-relaxed">
                TCP guarantees delivery with retransmissions, adding latency.
                UDP sends packets without waiting — ideal for real-time audio
                where low latency beats perfect delivery.
              </p>
            </div>
          </aside>
        </div>

        {/* Metric strip */}
        <div className="metric-grid mt-8">
          {metrics.map((metric) => (
            <div key={metric.label} className="metric">
              <span className="label">{metric.label}</span>
              <strong>{metric.value}</strong>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
