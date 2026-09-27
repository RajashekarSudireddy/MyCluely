import SectionHead from "./SectionHead";

const layers = [
  {
    index: "L1",
    title: "Audio capture layer",
    items: [
      { name: "MicrophoneCapture", tech: "AVAudioEngine" },
      { name: "SystemAudioCapture", tech: "ScreenCaptureKit" },
      { name: "AudioManager", tech: "Thread-safe coordinator" },
    ],
  },
  {
    index: "L2",
    title: "Audio processing",
    items: [
      { name: "AudioBufferConverter", tech: "16kHz mono Float32" },
      { name: "PCM byte transform", tech: "Int16 little-endian" },
      { name: "RMS level meter", tech: "Real-time visualizer" },
    ],
  },
  {
    index: "L3",
    title: "Intelligence engines",
    items: [
      { name: "Gemini Live client", tech: "WebSocket streaming" },
      { name: "Speech transcriber", tech: "Apple SFSpeech" },
      { name: "Question detector", tech: "Grammar + debounce" },
    ],
  },
  {
    index: "L4",
    title: "Presentation layer",
    items: [
      { name: "FloatingHUDWindow", tech: "NSPanel + SwiftUI" },
      { name: "HUD theme", tech: "Native materials" },
      { name: "Dynamic auto-resize", tech: "PreferenceKey" },
    ],
  },
];

const techStack = [
  "Swift 6",
  "AppKit",
  "SwiftUI",
  "ScreenCaptureKit",
  "AVAudioEngine",
  "WebSockets",
  "Gemini Live API",
  "CryptoKit",
];

export default function Architecture() {
  return (
    <section id="architecture" className="section">
      <div className="wrap">
        <SectionHead
          index="03"
          label="Architecture"
          title="Engineered for native performance"
          copy="A pure Swift 6 pipeline: zero-compromise audio capture, real-time WebSocket streaming, and an Apple-native interface."
        />

        <div>
          {layers.map((layer, layerIndex) => (
            <div key={layer.index}>
              {layerIndex > 0 && (
                <div
                  className="w-px h-6 bg-line mx-auto"
                  aria-hidden="true"
                />
              )}
              <div className="panel p-6">
                <div className="flex items-baseline gap-4 pb-4 mb-4 border-b border-hairline">
                  <p className="rule-marker">{layer.index}</p>
                  <h3 className="text-sm font-semibold text-paper uppercase tracking-wider">
                    {layer.title}
                  </h3>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  {layer.items.map((item) => (
                    <div
                      key={item.name}
                      className="rounded-lg border border-hairline bg-coal p-4"
                    >
                      <p className="text-[15px] font-medium text-paper">
                        {item.name}
                      </p>
                      <p className="label mt-1">{item.tech}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="flex flex-wrap gap-2 mt-8">
          {techStack.map((tech) => (
            <span
              key={tech}
              className="label rounded-lg border border-hairline px-4 py-2"
            >
              {tech}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}
