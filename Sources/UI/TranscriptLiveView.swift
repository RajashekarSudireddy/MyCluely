import SwiftUI

@MainActor
public struct TranscriptLiveView: View {
    @ObservedObject var appState: AppState
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public init() {
        self.appState = AppState.shared
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Equalizer Bars
            HStack(spacing: 2.5) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(appState.isPaused ? Theme.pausedColor : (appState.answeringMode == .liveStreaming ? Theme.liveBadgeColor : Theme.listeningColor))
                        .frame(width: 3, height: barHeight(for: index))
                        .animation(.spring(response: 0.18, dampingFraction: 0.5), value: appState.audioLevel)
                }
            }
            .frame(width: 20, height: 18)
            
            // Speech Text or State
            Group {
                if appState.isPaused {
                    Text("Paused • Click Listen to resume")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Theme.pausedColor)
                        .lineLimit(1)
                } else if appState.liveTranscript.isEmpty {
                    Text("Listening for questions...")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                } else {
                    Text(appState.liveTranscript)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .truncationMode(.head)
                }
            }
            
            Spacer(minLength: 4)
            
            // Engine Status Pill
            if appState.answeringMode == .liveStreaming {
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.liveStreamingStatus.contains("Active") ? Color.cyan : (appState.liveStreamingStatus.contains("Reconnecting") ? Color.orange : Color.gray))
                        .frame(width: 5, height: 5)
                        .shadow(color: Color.cyan.opacity(0.6), radius: 3)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.cyan)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.cyan.opacity(0.12))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                )
                .help("24/7 Gemini Live Cloud Stream (\(appState.liveStreamingStatus))")
            } else {
                Text("LOCAL")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.innerCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.innerCornerRadius)
                .stroke(Theme.borderStroke, lineWidth: 1)
        )
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if appState.isPaused { return 4 }
        let factor = CGFloat(index + 1) * 0.25
        let base: CGFloat = 3.5
        let dynamic = CGFloat(appState.audioLevel) * 14 * factor
        return min(16, max(base, base + dynamic))
    }
}
