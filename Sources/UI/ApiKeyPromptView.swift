import SwiftUI
import AppKit

public struct ApiKeyPromptView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var authManager: AuthManager = .shared
    
    @State private var selectedProvider: AIProvider
    @State private var inputKey: String = ""
    @State private var showKey: Bool = false
    @State private var pasteFeedback: Bool = false
    @State private var errorMessage: String? = nil
    
    public init(appState: AppState) {
        self.appState = appState
        _selectedProvider = State(initialValue: appState.aiProvider)
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header
            headerSection
            
            // Provider Selection Segment
            providerSelectionSection
            
            // Error Message
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 10.5))
                        .foregroundColor(.red)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .cornerRadius(6)
            }
            
            // API Key Input Card
            inputSection
            
            // Save & Activate Button
            saveButton
            
            // Footer with user email and Sign Out
            footerSection
        }
        .padding(16)
        .frame(width: 372)
        .onAppear {
            syncInputKeyForProvider()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: selectedProvider == .gemini
                                ? [Color.cyan.opacity(0.3), Theme.accentColor.opacity(0.2)]
                                : [Color.green.opacity(0.3), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: selectedProvider.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(selectedProvider == .gemini ? Color.cyan : Color.green)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(selectedProvider == .gemini ? "Activate Gemini Live" : "Activate OpenAI Live")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(selectedProvider.shortName)
                        .font(.system(size: 8.5, weight: .black))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(selectedProvider == .gemini ? Color.cyan.opacity(0.18) : Color.green.opacity(0.18))
                        .foregroundColor(selectedProvider == .gemini ? Color.cyan : Color.green)
                        .cornerRadius(4)
                }
                
                let userName = authManager.currentUser?.displayName ?? "User"
                Text("Welcome, \(userName). Paste your \(selectedProvider == .gemini ? "Gemini" : "OpenAI") API key to start real-time monitoring.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Provider Selector
    
    private var providerSelectionSection: some View {
        HStack(spacing: 6) {
            ForEach(AIProvider.allCases) { provider in
                let isSelected = selectedProvider == provider
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedProvider = provider
                        appState.aiProvider = provider
                        errorMessage = nil
                        syncInputKeyForProvider()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 10.5))
                        Text(provider.rawValue)
                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isSelected ? Theme.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                    .foregroundColor(isSelected ? Theme.accentColor : .primary)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Theme.accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(selectedProvider == .gemini ? "GEMINI API KEY" : "OPENAI API KEY")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                Spacer()
                
                if selectedProvider == .gemini {
                    Link("Get Free API Key ↗", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(Theme.accentColor)
                } else {
                    Link("Get OpenAI Key ↗", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(Theme.accentColor)
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                let placeholder = selectedProvider == .gemini ? "AIzaSy..." : "sk-..."
                let securePlaceholder = selectedProvider == .gemini ? "Paste your Gemini API key here..." : "Paste your OpenAI API key here..."
                
                if showKey {
                    TextField(placeholder, text: $inputKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .onSubmit(handleSave)
                } else {
                    SecureField(securePlaceholder, text: $inputKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .onSubmit(handleSave)
                }
                
                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(showKey ? "Hide Key" : "Show Key")
                
                Button(action: pasteFromClipboard) {
                    HStack(spacing: 3) {
                        Image(systemName: pasteFeedback ? "checkmark" : "doc.on.clipboard")
                        Text(pasteFeedback ? "Pasted" : "Paste")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pasteFeedback ? .green : .primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(Theme.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonCornerRadius)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: handleSave) {
            HStack(spacing: 6) {
                Image(systemName: selectedProvider.iconName)
                    .font(.system(size: 11))
                Text("Save & Activate MyCluely (\(selectedProvider.shortName))")
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Theme.accentColor, Color(red: 0.1, green: 0.45, blue: 0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .foregroundColor(.white)
            .cornerRadius(Theme.buttonCornerRadius)
            .shadow(color: Theme.accentColor.opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            if let email = authManager.currentUser?.email {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text(email)
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button("Sign Out") {
                withAnimation {
                    appState.signOut()
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
    
    // MARK: - Actions
    
    private func syncInputKeyForProvider() {
        if selectedProvider == .gemini {
            inputKey = authManager.currentUser?.geminiApiKey ?? appState.apiKey
        } else {
            inputKey = authManager.currentUser?.openaiApiKey ?? appState.openAIApiKey
        }
    }
    
    private func handleSave() {
        errorMessage = nil
        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please paste a valid \(selectedProvider == .gemini ? "Gemini" : "OpenAI") API key to proceed."
            return
        }
        
        do {
          try withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            appState.aiProvider = selectedProvider
            if selectedProvider == .gemini {
                try authManager.saveGeminiApiKey(trimmed)
                if appState.answeringMode == .liveStreaming {
                    GeminiLiveClient.shared.restart()
                }
            } else {
                try authManager.saveOpenAIApiKey(trimmed)
                if appState.answeringMode == .liveStreaming {
                    OpenAILiveClient.shared.restart()
                }
            }
          }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func pasteFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                inputKey = trimmed
                withAnimation { pasteFeedback = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { pasteFeedback = false }
                }
            }
        }
    }
}
