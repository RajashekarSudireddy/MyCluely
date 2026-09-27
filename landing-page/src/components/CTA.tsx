const trustItems = [
  "No account required",
  "Open source",
  "MIT License",
];

export default function CTA() {
  return (
    <section className="section section-plain">
      <div className="wrap">
        <div className="panel p-8 sm:p-12 md:p-16 text-center">
          <p className="eyebrow mb-4">Get started</p>
          <h2 className="type-h1 max-w-2xl mx-auto">
            Never miss another answer.
          </h2>
          <p className="section-copy mx-auto mt-4 mb-8 text-center">
            Download MyCluely and start getting instant AI answers from every
            meeting, lecture, and conversation — in under 60 seconds.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
            <a href="#pricing" className="btn btn-primary w-full sm:w-auto">
              <span className="flex items-center gap-2">
                Download for macOS — Free
                <svg
                  className="w-4 h-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M17 8l4 4m0 0l-4 4m4-4H3"
                  />
                </svg>
              </span>
            </a>
            <a
              href="https://github.com"
              target="_blank"
              rel="noopener noreferrer"
              className="btn btn-secondary w-full sm:w-auto"
            >
              View on GitHub
            </a>
          </div>

          <div className="flex flex-wrap items-center justify-center gap-x-6 gap-y-2 mt-8">
            {trustItems.map((item) => (
              <span key={item} className="flex items-center gap-2">
                <svg
                  className="w-4 h-4 text-structural"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M5 13l4 4L19 7"
                  />
                </svg>
                <span className="text-sm text-muted">{item}</span>
              </span>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
