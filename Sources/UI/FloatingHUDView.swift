import SwiftUI
import AppKit

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

public struct FloatingHUDView: View {
    @ObservedObject var appState: AppState = .shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            if !appState.isAuthenticated {
                // Application Protection: Login / Sign Up / Google Auth
                AuthView(appState: appState)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
            } else if appState.authManager.needsApiKey {
                // Mandatory Per-User Gemini API Key Setup
                ApiKeyPromptView(appState: appState)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
            } else if appState.showSettings {
                // In-panel Settings View with smooth transition
                SettingsPopoverView(appState: appState, isPresented: $appState.showSettings)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
            } else {
                // Main Live HUD View
                mainHUDContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
            }
        }
        .frame(width: (appState.isAuthenticated && !appState.authManager.needsApiKey && appState.isPillMode) ? 280 : 400)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Theme.hudBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(Theme.borderStroke, lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 16, x: 0, y: 8)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self) { newHeight in
            if newHeight > 0 {
                FloatingHUDWindow.shared?.updateHeight(newHeight)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.showSettings)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.isPillMode)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.activeQA)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.isAuthenticated)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.authManager.needsApiKey)
    }
    
    // MARK: - Main HUD Content
    private var mainHUDContent: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar
            
            if !appState.isPillMode {
                VStack(spacing: 8) {
                    // Permission Banner
                    if let message = appState.permissionMessage {
                        permissionBanner(message)
                    }
                    
                    // Live Transcript & Visualizer
                    TranscriptLiveView(appState: appState)
                    
                    // Active Q&A Card
                    if let active = appState.activeQA {
                        QuestionAnswerCard(
                            item: active,
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    appState.dismissActiveQA()
                                }
                            },
                            onRegenerate: {
                                AnswerService.shared.generateAnswer(for: active)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    
                    // History Drawer
                    if appState.showHistory && !appState.history.isEmpty {
                        historySection
                    }
                }
                .padding([.horizontal, .bottom], 10)
                .padding(.top, 2)
            }
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 7) {
            // Pulsing Live Indicator Dot
            Circle()
                .fill(appState.isPaused ? Theme.pausedColor : Theme.listeningColor)
                .frame(width: 8, height: 8)
                .shadow(color: (appState.isPaused ? Theme.pausedColor : Theme.listeningColor).opacity(0.7), radius: 4)
            
            Text("MyCluely")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Audio Source Pill
            HStack(spacing: 3) {
                Image(systemName: appState.audioSource.iconName)
                    .font(.system(size: 9))
                Text(appState.audioSource.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(4)
            
            // AI Model Pill
            HStack(spacing: 3) {
                Image(systemName: appState.aiProvider.iconName)
                    .font(.system(size: 9))
                Text(appState.aiProvider.shortName)
                    .font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundColor(appState.aiProvider == .gemini ? Color.cyan : Color.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background((appState.aiProvider == .gemini ? Color.cyan : Color.green).opacity(0.12))
            .cornerRadius(4)
            
            Spacer()
            
            // Listen / Pause Pill Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    appState.togglePause()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: appState.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 9.5))
                    Text(appState.isPaused ? "Listen" : "Pause")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(appState.isPaused ? Theme.listeningColor.opacity(0.18) : Theme.pausedColor.opacity(0.18))
                .foregroundColor(appState.isPaused ? Theme.listeningColor : Theme.pausedColor)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(appState.isPaused ? Theme.listeningColor.opacity(0.35) : Theme.pausedColor.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(appState.isPaused ? "Resume hearing" : "Pause hearing")
            
            // History Button
            if !appState.isPillMode && !appState.history.isEmpty {
                iconButton(systemName: "clock.arrow.circlepath", isSelected: appState.showHistory) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        appState.showHistory.toggle()
                    }
                }
                .help("Recent Q&A History")
            }
            
            // Settings Button
            iconButton(systemName: "gearshape.fill", isSelected: appState.showSettings) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    appState.showSettings.toggle()
                }
            }
            .help("Settings")
            
            // Minimize Pill Button
            iconButton(systemName: appState.isPillMode ? "arrow.up.left.and.arrow.down.right" : "minus", isSelected: false) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    appState.isPillMode.toggle()
                }
            }
            .help(appState.isPillMode ? "Expand HUD" : "Collapse to pill")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
    
    private func iconButton(systemName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? Theme.accentColor : .secondary)
                .frame(width: 22, height: 22)
                .background(isSelected ? Theme.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Permission Banner
    private func permissionBanner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 11))
            
            Text(message)
                .font(.system(size: 10.5))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            Button("Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            
            Button(action: {
                withAnimation { appState.permissionMessage = nil }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(7)
        .background(Color.orange.opacity(0.14))
        .cornerRadius(Theme.buttonCornerRadius)
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("RECENT QUESTIONS")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                Spacer()
                Button("Clear") {
                    withAnimation { appState.clearHistory() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 5) {
                    ForEach(appState.history) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Q: \(item.question)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("A: \(item.answer)")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.cardBackground)
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 110)
        }
        .padding(.top, 2)
    }
}
