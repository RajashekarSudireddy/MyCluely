import SwiftUI
import AppKit

@MainActor
public struct SettingsPopoverView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    
    @State private var showGeminiApiKey: Bool = false
    @State private var showOpenAIApiKey: Bool = false
    @State private var pasteGeminiFeedback: Bool = false
    @State private var pasteOpenAIFeedback: Bool = false
    
    public init(appState: AppState, isPresented: Binding<Bool>) {
        self.appState = appState
        self._isPresented = isPresented
    }
    
    public init(isPresented: Binding<Bool>) {
        self.appState = AppState.shared
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            headerSection
            
            // Account Section
            accountSection
            
            // Audio Source Picker
            audioSourceSection
            
            // AI Model Provider
            aiProviderSection
            
            // AI Intelligence Engine
            intelligenceEngineSection
            
            // API Keys
            apiKeysSection
            
            // Toggles
            preferencesSection
            
            // Bottom Action Bar
            footerSection
        }
        .padding(14)
        .frame(width: 372)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isPresented = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Settings")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Done") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isPresented = false
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACCOUNT & SECURITY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            if let user = appState.currentUser {
                HStack(spacing: 10) {
                    // Avatar / Badge
                    ZStack {
                        Circle()
                            .fill(user.authProvider == .google ? Color.white : Theme.accentColor.opacity(0.18))
                            .frame(width: 32, height: 32)
                        
                        if user.authProvider == .google {
                            GoogleLogoView(size: 16)
                        } else {
                            Text(String(user.displayName.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.accentColor)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 1.5) {
                        HStack(spacing: 5) {
                            Text(user.displayName)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 3) {
                                Image(systemName: user.authProvider.iconName)
                                    .font(.system(size: 8))
                                Text(user.authProvider.rawValue)
                                    .font(.system(size: 8.5, weight: .medium))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(user.authProvider == .google ? Color.blue.opacity(0.12) : Color.primary.opacity(0.08))
                            .foregroundColor(user.authProvider == .google ? Color.blue : .secondary)
                            .cornerRadius(4)
                        }
                        
                        Text(user.email)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Sign Out Button
                    Button(action: {
                        withAnimation {
                            isPresented = false
                            appState.signOut()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 9.5))
                            Text("Sign Out")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Sign out and lock application")
                }
                .padding(9)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(Theme.innerCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.innerCornerRadius)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Audio Source
    private var audioSourceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AUDIO CAPTURE SOURCE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            HStack(spacing: 6) {
                ForEach(AudioSourceType.allCases) { source in
                    let isSelected = appState.audioSource == source
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            appState.audioSource = source
                        }
                        Task {
                            appState.permissionMessage = nil
                            try? await AudioManager.shared.switchSource(to: source)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: source.iconName)
                                .font(.system(size: 11))
                            Text(source.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? Theme.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                        .foregroundColor(isSelected ? Theme.accentColor : .primary)
                        .cornerRadius(Theme.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                                .stroke(isSelected ? Theme.accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - AI Model Provider
    private var aiProviderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI MODEL PROVIDER")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            HStack(spacing: 6) {
                ForEach(AIProvider.allCases) { provider in
                    let isSelected = appState.aiProvider == provider
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            appState.aiProvider = provider
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: provider.iconName)
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? Theme.accentColor : .secondary)
                            Text(provider.shortName)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? Theme.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                        .foregroundColor(isSelected ? Theme.accentColor : .primary)
                        .cornerRadius(Theme.buttonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                                .stroke(isSelected ? Theme.accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Intelligence Engine
    private var intelligenceEngineSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INTELLIGENCE ENGINE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            VStack(spacing: 6) {
                // Cloud Live Option Card
                let liveTitle = appState.aiProvider == .gemini
                    ? "24/7 Cloud Live (Gemini Live)"
                    : "24/7 Cloud Live (OpenAI Realtime)"
                let liveSubtitle = appState.aiProvider == .gemini
                    ? "Continuous raw audio stream to gemini-3.1-flash-live with minimum latency."
                    : "Real-time 24kHz bi-directional WebSocket stream to OpenAI gpt-realtime."
                
                engineCard(
                    mode: .liveStreaming,
                    icon: appState.aiProvider.iconName,
                    iconColor: appState.aiProvider == .gemini ? Color.cyan : Color.green,
                    title: liveTitle,
                    subtitle: liveSubtitle,
                    statusBadge: appState.liveStreamingStatus.contains("Active") ? "Connected" : nil
                )
                
                // Local STT Option Card
                engineCard(
                    mode: .localSTT,
                    icon: "cpu",
                    iconColor: Theme.questionColor,
                    title: "Local STT + Fast REST",
                    subtitle: "Apple Speech recognition with REST fallback.",
                    statusBadge: nil
                )
            }
        }
    }
    
    private func engineCard(mode: AnsweringMode, icon: String, iconColor: Color, title: String, subtitle: String, statusBadge: String?) -> some View {
        let isSelected = appState.answeringMode == mode
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.answeringMode = mode
            }
        }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(iconColor)
                    .frame(width: 18)
                    .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(.primary)
                        
                        if let badge = statusBadge {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                                Text(badge)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? Theme.accentColor : .secondary.opacity(0.5))
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)
            .background(isSelected ? Theme.accentColor.opacity(0.1) : Color.primary.opacity(0.04))
            .cornerRadius(Theme.innerCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.innerCornerRadius)
                    .stroke(isSelected ? Theme.accentColor.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - API Keys
    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("API CREDENTIALS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            // Gemini API Key Field
            apiKeyRow(
                title: "GOOGLE GEMINI API KEY",
                key: $appState.apiKey,
                showKey: $showGeminiApiKey,
                pasteFeedback: $pasteGeminiFeedback,
                getKeyUrl: "https://aistudio.google.com/app/apikey",
                isActiveProvider: appState.aiProvider == .gemini,
                placeholder: "AIzaSy..."
            )
            
            // OpenAI API Key Field
            apiKeyRow(
                title: "OPENAI API KEY (gpt-realtime)",
                key: $appState.openAIApiKey,
                showKey: $showOpenAIApiKey,
                pasteFeedback: $pasteOpenAIFeedback,
                getKeyUrl: "https://platform.openai.com/api-keys",
                isActiveProvider: appState.aiProvider == .openAI,
                placeholder: "sk-..."
            )
        }
    }
    
    private func apiKeyRow(
        title: String,
        key: Binding<String>,
        showKey: Binding<Bool>,
        pasteFeedback: Binding<Bool>,
        getKeyUrl: String,
        isActiveProvider: Bool,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(isActiveProvider ? .primary : .secondary)
                        .tracking(0.4)
                    
                    if isActiveProvider {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.accentColor.opacity(0.18))
                            .foregroundColor(Theme.accentColor)
                            .cornerRadius(3)
                    }
                }
                
                Spacer()
                
                Link("Get Key ↗", destination: URL(string: getKeyUrl)!)
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.accentColor)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11))
                    .foregroundColor(isActiveProvider ? Theme.accentColor : .secondary)
                
                if showKey.wrappedValue {
                    TextField(placeholder, text: key)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                } else {
                    SecureField(placeholder, text: key)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                
                Button(action: { showKey.wrappedValue.toggle() }) {
                    Image(systemName: showKey.wrappedValue ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(showKey.wrappedValue ? "Hide Key" : "Show Key")
                
                Button(action: {
                    pasteKey(to: key, feedback: pasteFeedback)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: pasteFeedback.wrappedValue ? "checkmark" : "doc.on.clipboard")
                        Text(pasteFeedback.wrappedValue ? "Pasted" : "Paste")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pasteFeedback.wrappedValue ? .green : .primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(Theme.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                    .stroke(isActiveProvider ? Theme.accentColor.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Preferences
    private var preferencesSection: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $appState.autoAnswer) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auto-generate answers")
                        .font(.system(size: 11, weight: .medium))
                    Text("Instantly fetches answer when question is asked")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            Toggle(isOn: $appState.speakAnswersAloud) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Speak answers aloud")
                        .font(.system(size: 11, weight: .medium))
                    Text("Voice audio playback (headphones recommended)")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(Theme.innerCornerRadius)
    }
    
    // MARK: - Footer
    private var footerSection: some View {
        HStack {
            Button("Privacy Settings ↗") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.system(size: 10))
            .buttonStyle(.link)
            
            Spacer()
            
            Text("MyCluely v1.2.0 • Native macOS")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.top, 2)
    }
    
    private func pasteKey(to binding: Binding<String>, feedback: Binding<Bool>) {
        if let str = NSPasteboard.general.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                binding.wrappedValue = trimmed
                withAnimation { feedback.wrappedValue = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { feedback.wrappedValue = false }
                }
            }
        }
    }
}
