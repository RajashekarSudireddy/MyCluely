import SectionHead from "./SectionHead";

const plans = [
  {
    name: "Free",
    price: "0",
    period: "forever",
    description: "Try MyCluely with your own Gemini API key.",
    features: [
      "Full native macOS app",
      "Microphone audio capture",
      "24/7 Gemini Live streaming",
      "Local STT + REST fallback",
      "Floating HUD with pill mode",
      "Global keyboard shortcuts",
      "Bring your own Gemini API key",
    ],
    cta: "Download Free",
    highlighted: false,
  },
  {
    name: "Pro",
    price: "12",
    period: "per month",
    description:
      "For professionals who live in meetings and want cloud-synced intelligence.",
    features: [
      "Everything in Free",
      "System + Mic dual audio capture",
      "Cloud-synced Q&A history",
      "Cross-device settings sync",
      "Priority model access",
      "Managed API key (no BYOK)",
      "Advanced question detection",
      "Email support",
    ],
    cta: "Start 14-Day Free Trial",
    highlighted: true,
  },
  {
    name: "Team",
    price: "29",
    period: "per user / month",
    description:
      "For teams that need shared intelligence, admin controls, and compliance.",
    features: [
      "Everything in Pro",
      "Team admin dashboard",
      "Shared Q&A knowledge base",
      "SSO / SAML authentication",
      "Usage analytics & reporting",
      "Custom system instructions",
      "Dedicated Slack support",
      "Volume discounts available",
    ],
    cta: "Contact Sales",
    highlighted: false,
  },
];

function CheckIcon() {
  return (
    <svg
      className="w-4 h-4 mt-1 shrink-0 text-structural"
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
  );
}

export default function Pricing() {
  return (
    <section id="pricing" className="section">
      <div className="wrap">
        <SectionHead
          index="04"
          label="Pricing"
          title="Start free, scale when ready"
          copy="MyCluely is free to use with your own Gemini API key. Upgrade for cloud sync, managed keys, and team features."
        />

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={
                plan.highlighted
                  ? "content-card"
                  : "panel p-6 grid gap-4 content-start"
              }
            >
              {plan.highlighted && (
                <p className="label text-paper">Most popular</p>
              )}
              <h3 className="type-h2">{plan.name}</h3>
              <p className="text-sm text-muted leading-relaxed">
                {plan.description}
              </p>

              <div className="flex items-baseline gap-2">
                <span className="type-h1">${plan.price}</span>
                <span className="text-sm text-muted">/{plan.period}</span>
              </div>

              <a
                href="#"
                className={`btn w-full ${
                  plan.highlighted ? "btn-primary" : "btn-secondary"
                }`}
              >
                {plan.cta}
              </a>

              <ul className="space-y-3 pt-2 border-t border-hairline">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-start gap-3">
                    <CheckIcon />
                    <span className="text-sm text-paper">{feature}</span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
