import Foundation
import SwiftUI
import Combine

public enum AudioSourceType: String, CaseIterable, Identifiable {
    case systemAudio = "System Audio"
    case microphone = "Microphone"
    case both = "System + Mic"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .systemAudio: return "speaker.wave.2.fill"
        case .microphone: return "mic.fill"
        case .both: return "waveform.and.mic"
        }
    }
}

public enum AIProvider: String, CaseIterable, Identifiable {
    case gemini = "Google Gemini Live"
    case openAI = "OpenAI Realtime (gpt-realtime)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .gemini: return "Gemini 3.1"
        case .openAI: return "GPT-Realtime"
        }
    }
    
    public var iconName: String {
        switch self {
        case .gemini: return "bolt.fill"
        case .openAI: return "waveform.circle.fill"
        }
    }
}

public enum AnsweringMode: String, CaseIterable, Identifiable {
    case liveStreaming = "24/7 Cloud Live (Gemini Live)"
    case localSTT = "Local STT + Fast REST"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .liveStreaming: return "Cloud Live"
        case .localSTT: return "Local STT"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // Authentication
    public let authManager = AuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    public var isAuthenticated: Bool {
        authManager.isAuthenticated
    }
    
    public var currentUser: UserProfile? {
        authManager.currentUser
    }
    
    // Hearing State
    @Published public var isListening: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var audioSource: AudioSourceType {
        didSet {
            UserDefaults.standard.set(audioSource.rawValue, forKey: "mycluely_audio_source")
        }
    }
    @Published public var audioLevel: Float = 0.0
    @Published public var permissionGranted: Bool = true
    @Published public var permissionMessage: String? = nil
    
    // Answering Engine Mode & Provider
    @Published public var aiProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(aiProvider.rawValue, forKey: "mycluely_ai_provider")
            handleProviderChange(aiProvider)
        }
    }
    @Published public var answeringMode: AnsweringMode {
        didSet {
            UserDefaults.standard.set(answeringMode.rawValue, forKey: "mycluely_answering_mode")
            handleModeChange(answeringMode)
        }
    }
    @Published public var speakAnswersAloud: Bool {
        didSet {
            UserDefaults.standard.set(speakAnswersAloud, forKey: "mycluely_speak_answers_aloud")
            GeminiLiveClient.shared.shouldSpeakAnswers = speakAnswersAloud
            OpenAILiveClient.shared.shouldSpeakAnswers = speakAnswersAloud
        }
    }
    @Published public var liveStreamingStatus: String = "Inactive"
    
    // Speech & QA
    @Published public var liveTranscript: String = ""
    @Published public var activeQA: QAItem? = nil
    @Published public var history: [QAItem] = []
    
    // UI Layout State
    @Published public var isPillMode: Bool = false
    @Published public var showSettings: Bool = false
    @Published public var showHistory: Bool = false
    
    // Configuration
    @Published public var apiKey: String {
        didSet {
            if let userEmail = authManager.currentUser?.email, authManager.currentUser?.geminiApiKey != apiKey {
                do { try AuthStorage.shared.updateGeminiApiKey(forEmail: userEmail, apiKey: apiKey) }
                catch {
                    apiKey = oldValue
                    permissionMessage = CredentialStorageError.unavailable.localizedDescription
                    return
                }
                authManager.currentUser?.geminiApiKey = apiKey
            }
            if isListening && isAuthenticated && answeringMode == .liveStreaming && aiProvider == .gemini {
                GeminiLiveClient.shared.restart()
            }
        }
    }
    @Published public var openAIApiKey: String {
        didSet {
            if let userEmail = authManager.currentUser?.email, authManager.currentUser?.openaiApiKey != openAIApiKey {
                do { try AuthStorage.shared.updateOpenAIApiKey(forEmail: userEmail, apiKey: openAIApiKey) }
                catch {
                    openAIApiKey = oldValue
                    permissionMessage = CredentialStorageError.unavailable.localizedDescription
                    return
                }
                authManager.currentUser?.openaiApiKey = openAIApiKey
            }
            if isListening && isAuthenticated && answeringMode == .liveStreaming && aiProvider == .openAI {
                OpenAILiveClient.shared.restart()
            }
        }
    }
    @Published public var modelName: String {
        didSet {
            UserDefaults.standard.set(modelName, forKey: "mycluely_model_name")
        }
    }
    @Published public var openAIModelName: String {
        didSet {
            UserDefaults.standard.set(openAIModelName, forKey: "mycluely_openai_model_name")
            if isListening && isAuthenticated && answeringMode == .liveStreaming && aiProvider == .openAI {
                OpenAILiveClient.shared.restart()
            }
        }
    }
    @Published public var autoAnswer: Bool {
        didSet {
            UserDefaults.standard.set(autoAnswer, forKey: "mycluely_auto_answer")
        }
    }
    
    public init() {
        let storedProvider = UserDefaults.standard.string(forKey: "mycluely_ai_provider")
        let storedKey = authManager.currentUser?.geminiApiKey ?? ""
        let storedOpenAIKey = authManager.currentUser?.openaiApiKey ?? ""

        let storedModel = UserDefaults.standard.string(forKey: "mycluely_model_name")
            ?? UserDefaults.standard.string(forKey: "audiohud_model_name") ?? "gemini-2.5-flash"
        let storedOpenAIModel = UserDefaults.standard.string(forKey: "mycluely_openai_model_name") ?? "gpt-realtime"
        let effectiveOpenAIModel: String
        if storedOpenAIModel.contains("gpt-live") || storedOpenAIModel.contains("gpt-4o-realtime-preview") {
            effectiveOpenAIModel = "gpt-realtime"
        } else {
            effectiveOpenAIModel = storedOpenAIModel
        }
        
        let storedAuto = (UserDefaults.standard.object(forKey: "mycluely_auto_answer")
            ?? UserDefaults.standard.object(forKey: "audiohud_auto_answer")) as? Bool ?? true
        let storedSource = UserDefaults.standard.string(forKey: "mycluely_audio_source")
            ?? UserDefaults.standard.string(forKey: "audiohud_audio_source")
        let storedMode = UserDefaults.standard.string(forKey: "mycluely_answering_mode")
            ?? UserDefaults.standard.string(forKey: "audiohud_answering_mode")
        let storedSpeak = UserDefaults.standard.object(forKey: "mycluely_speak_answers_aloud") as? Bool
            ?? UserDefaults.standard.bool(forKey: "audiohud_speak_answers_aloud")
        
        self.aiProvider = storedProvider.flatMap { stored in
            if stored.contains("OpenAI") || stored.contains("gpt-live") || stored.contains("gpt-realtime") {
                return .openAI
            }
            return AIProvider(rawValue: stored)
        } ?? .gemini
        self.apiKey = storedKey
        self.openAIApiKey = storedOpenAIKey
        self.modelName = storedModel
        self.openAIModelName = effectiveOpenAIModel
        self.autoAnswer = storedAuto
        // Default to Microphone
        self.audioSource = storedSource.flatMap { AudioSourceType(rawValue: $0) } ?? .microphone
        // Default to 24/7 Cloud Live Streaming
        self.answeringMode = storedMode.flatMap { AnsweringMode(rawValue: $0) } ?? .liveStreaming
        self.speakAnswersAloud = storedSpeak
        
        // Forward AuthManager updates to trigger UI refresh
        authManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    public func signOut() {
        authManager.signOut()
        self.liveTranscript = ""
        self.activeQA = nil
        self.history.removeAll()
        self.showSettings = false
        self.showHistory = false
        self.isListening = false
        self.audioLevel = 0.0
        self.apiKey = ""
        self.openAIApiKey = ""
    }
    
    public func handleModeChange(_ mode: AnsweringMode) {
        guard isListening && isAuthenticated else { return }
        if mode == .liveStreaming {
            SpeechTranscriber.shared.stop()
            switch aiProvider {
            case .gemini:
                OpenAILiveClient.shared.stop()
                GeminiLiveClient.shared.start()
            case .openAI:
                GeminiLiveClient.shared.stop()
                OpenAILiveClient.shared.start()
            }
        } else {
            GeminiLiveClient.shared.stop()
            OpenAILiveClient.shared.stop()
            SpeechTranscriber.shared.start()
        }
    }
    
    public func handleProviderChange(_ provider: AIProvider) {
        guard isListening && isAuthenticated else { return }
        if answeringMode == .liveStreaming {
            switch provider {
            case .gemini:
                OpenAILiveClient.shared.stop()
                GeminiLiveClient.shared.start()
            case .openAI:
                GeminiLiveClient.shared.stop()
                OpenAILiveClient.shared.start()
            }
        }
    }
    
    public func togglePause() {
        isPaused.toggle()
        AudioManager.shared.isPaused = isPaused
        if isPaused {
            audioLevel = 0.0
        }
    }
    
    public func dismissActiveQA() {
        if let current = activeQA {
            if !history.contains(where: { $0.id == current.id }) {
                history.insert(current, at: 0)
                if history.count > 30 { history.removeLast() }
            }
        }
        activeQA = nil
    }
    
    public func clearHistory() {
        history.removeAll()
    }
}
