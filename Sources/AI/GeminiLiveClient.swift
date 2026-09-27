import Foundation
import AVFoundation
import AppKit

public final class GeminiLiveClient: @unchecked Sendable {
    public static let shared = GeminiLiveClient()
    
    private let queue = DispatchQueue(label: "com.mycluely.geminilive", qos: .userInitiated)
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var ownerSessionID: UUID?
    private var isRunning: Bool = false
    private var isSetupComplete: Bool = false
    private var isReconnecting: Bool = false
    private var reconnectAttempts: Int = 0
    
    // Accumulation buffer for 16kHz 16-bit PCM audio (chunked every ~100ms = 3200 bytes)
    private var pendingAudioData = Data()
    private let targetChunkSizeBytes = 3200 // 1600 samples * 2 bytes = 100ms at 16kHz
    
    // State tracking for Q&A
    private var currentSpokenQuestion: String = ""
    private var currentAnswerAccumulator: String = ""
    private var wasPaused: Bool = false
    
    // Audio playback for optional spoken output
    private let lock = NSLock()
    private var _shouldSpeakAnswers: Bool = false
    public var shouldSpeakAnswers: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _shouldSpeakAnswers
        }
        set {
            lock.lock()
            _shouldSpeakAnswers = newValue
            lock.unlock()
        }
    }
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioOutputFormat: AVAudioFormat?
    
    public var isActive: Bool {
        return isRunning
    }
    
    private init() {
        self._shouldSpeakAnswers = UserDefaults.standard.object(forKey: "mycluely_speak_answers_aloud") as? Bool
            ?? UserDefaults.standard.bool(forKey: "audiohud_speak_answers_aloud")
        setupAudioPlayer()
    }
    
    // MARK: - Lifecycle
    
    public func start() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isRunning else { return }
            self.isRunning = true
            self.reconnectAttempts = 0
            self.connectWebSocket()
        }
    }
    
    public func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isRunning = false
            self.isSetupComplete = false
            self.disconnectWebSocket()
            self.pendingAudioData.removeAll()
            self.currentSpokenQuestion = ""
            self.currentAnswerAccumulator = ""
            self.wasPaused = false
            self.stopAudioPlayback()
            
            Task { @MainActor in
                AppState.shared.liveStreamingStatus = "Inactive"
            }
        }
    }
    
    public func restart() {
        stop()
        queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.start()
        }
    }
    
    // MARK: - Audio Ingestion
    
    public func appendAudioBuffer(_ pcmBuffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            let isPaused = AudioManager.shared.isPaused
            if isPaused {
                if !self.wasPaused {
                    self.wasPaused = true
                    self.sendAudioStreamEnd()
                }
                return
            } else if self.wasPaused {
                self.wasPaused = false
            }
            
            // Convert Float32 16kHz samples to 16-bit signed PCM little-endian
            let frameCount = Int(pcmBuffer.frameLength)
            guard frameCount > 0, let floatChannel = pcmBuffer.floatChannelData?[0] else { return }
            
            var pcm16Data = Data(capacity: frameCount * 2)
            for i in 0..<frameCount {
                let sample = max(-1.0, min(1.0, floatChannel[i]))
                var int16Sample = Int16(sample * 32767.0).littleEndian
                withUnsafeBytes(of: &int16Sample) { bytes in
                    pcm16Data.append(contentsOf: bytes)
                }
            }
            
            self.pendingAudioData.append(pcm16Data)
            
            // Only stream if setup has completed on server
            guard self.isSetupComplete, self.webSocketTask != nil else {
                // Keep last 1 second of audio in buffer while connecting
                if self.pendingAudioData.count > 32000 {
                    self.pendingAudioData = self.pendingAudioData.suffix(32000)
                }
                return
            }
            
            // Flush chunks of ~100ms
            while self.pendingAudioData.count >= self.targetChunkSizeBytes {
                let chunk = self.pendingAudioData.prefix(self.targetChunkSizeBytes)
                self.pendingAudioData.removeFirst(self.targetChunkSizeBytes)
                self.sendAudioChunk(Data(chunk))
            }
        }
    }
    
    // MARK: - WebSocket Connection
    
    private func connectWebSocket() {
        disconnectWebSocket()
        let owner = DispatchQueue.main.sync { () -> UUID? in
            guard AuthManager.shared.isAuthenticated else { return nil }
            return AuthManager.shared.sessionID
        }
        guard let owner = owner else { isRunning = false; return }
        ownerSessionID = owner

        var apiKey = ""
        if Thread.isMainThread {
            apiKey = MainActor.assumeIsolated {
                AppState.shared.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            apiKey = DispatchQueue.main.sync {
                AppState.shared.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if apiKey.isEmpty {
            Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                AppState.shared.liveStreamingStatus = "API Key Required"
                AppState.shared.permissionMessage = "Enter your Google Gemini API key to enable 24/7 Live Cloud Streaming."
            }
            return
        }
        
        Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
            AppState.shared.liveStreamingStatus = "Connecting..."
        }
        
        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        guard let url = URL(string: urlString) else {
            print("[GeminiLiveClient] Invalid WebSocket URL")
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30.0
        self.session = URLSession(configuration: config)
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let task = session!.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()
        
        print("[GeminiLiveClient] WebSocket connecting to Gemini Live API...")
        sendSetupMessage()
        listenForMessages()
    }
    
    private func disconnectWebSocket() {
        isSetupComplete = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
    }
    
    // MARK: - Protocol Messages
    
    private func sendSetupMessage() {
        let setupPayload: [String: Any] = [
            "setup": [
                "model": "models/gemini-3.1-flash-live-preview",
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": [
                                "voiceName": "Puck"
                            ]
                        ]
                    ]
                ],
                "inputAudioTranscription": [String: Any](),
                "outputAudioTranscription": [String: Any](),
                "systemInstruction": [
                    "parts": [
                        [
                            "text": "You are MyCluely, an ultra-fast real-time speech assistant and co-pilot. You listen continuously to live audio stream from meetings, discussions, and conversations. When anyone asks a question, makes an inquiry, or requests information, formulate a concise, direct, accurate answer immediately. State the answer in 1 to 2 clear sentences or compact bullet points (maximum 50 words). No pleasantries, no greetings, no introductory filler. If people are just chatting or discussing without asking a question, remain completely silent."
                        ]
                    ]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: setupPayload, options: []) else { return }
        webSocketTask?.send(.data(jsonData)) { [weak self] error in
            if error != nil {
                print("[GeminiLiveClient] Setup send error (details omitted)")
                self?.handleConnectionFailure()
            } else {
                print("[GeminiLiveClient] Setup message sent to Gemini Live API")
            }
        }
    }
    
    private func sendAudioChunk(_ pcmData: Data) {
        let base64String = pcmData.base64EncodedString()
        let audioMessage: [String: Any] = [
            "realtimeInput": [
                "audio": [
                    "mimeType": "audio/pcm;rate=16000",
                    "data": base64String
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: audioMessage) else { return }
        webSocketTask?.send(.data(jsonData)) { [weak self] error in
            if error != nil {
                print("[GeminiLiveClient] Audio chunk send error (details omitted)")
                self?.handleConnectionFailure()
            }
        }
    }
    
    private func sendAudioStreamEnd() {
        let endMessage: [String: Any] = [
            "realtimeInput": [
                "audioStreamEnd": true
            ]
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: endMessage) else { return }
        webSocketTask?.send(.data(jsonData)) { _ in }
    }
    
    // MARK: - Message Receiver Loop
    
    private func listenForMessages() {
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }
            self.queue.async {
                guard self.isRunning, self.webSocketTask === task else { return }
                switch result {
                case .success(let message):
                    self.processWebSocketMessage(message)
                    self.listenForMessages()
                case .failure:
                    print("[GeminiLiveClient] WebSocket receive failed (details omitted)")
                    self.handleConnectionFailure()
                }
            }
        }
    }

    private func processWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        var rawData: Data?
        switch message {
        case .string(let text):
            rawData = text.data(using: .utf8)
        case .data(let data):
            rawData = data
        @unknown default:
            break
        }
        
        guard let data = rawData,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // 1. Setup Complete
        if json["setupComplete"] != nil {
            print("[GeminiLiveClient] Setup Complete received! Live session active.")
            isSetupComplete = true
            reconnectAttempts = 0
            Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                AppState.shared.liveStreamingStatus = "Live Cloud Streaming Active"
                AppState.shared.permissionMessage = nil
            }
            return
        }
        
        // 2. Server Content
        if let serverContent = json["serverContent"] as? [String: Any] {
            // Input Audio Transcription (User Speech)
            if let inTrans = serverContent["inputTranscription"] as? [String: Any],
               let text = inTrans["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.currentSpokenQuestion = cleaned
                Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                    AppState.shared.liveTranscript = cleaned
                }
            }
            
            // Interim Input Audio Transcription
            if let interim = serverContent["interimInputTranscription"] as? [String: Any],
               let text = interim["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.currentSpokenQuestion = cleaned
                Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                    AppState.shared.liveTranscript = cleaned
                }
            }
            
            // Output Audio Transcription (Model Answer Text Stream)
            if let outTrans = serverContent["outputTranscription"] as? [String: Any],
               let text = outTrans["text"] as? String, !text.isEmpty {
                handleStreamingAnswerChunk(text)
            }
            
            // Model Turn Parts
            if let modelTurn = serverContent["modelTurn"] as? [String: Any],
               let parts = modelTurn["parts"] as? [[String: Any]] {
                for part in parts {
                    // Text part if present
                    if let text = part["text"] as? String, !text.isEmpty {
                        handleStreamingAnswerChunk(text)
                    }
                    // Audio PCM part if spoken answers are enabled
                    if let inlineData = part["inlineData"] as? [String: Any],
                       let base64 = inlineData["data"] as? String,
                       let pcmData = Data(base64Encoded: base64) {
                        playAudioPcmData(pcmData)
                    }
                }
            }
            
            // Interrupted Signal (User started speaking while model was outputting)
            if let interrupted = serverContent["interrupted"] as? Bool, interrupted {
                print("[GeminiLiveClient] Model response interrupted by user speech")
                stopAudioPlayback()
            }
            
            // Turn Complete Signal
            if let turnComplete = serverContent["turnComplete"] as? Bool, turnComplete {
                finalizeCurrentAnswer()
            }
        }
        
        // 3. GoAway Signal (Server indicates connection is retiring)
        if json["goAway"] != nil {
            print("[GeminiLiveClient] Server sent GoAway. Gracefully reconnecting...")
            queue.async { [weak self] in
                self?.connectWebSocket()
            }
        }
    }
    
    // MARK: - Answer Streaming to HUD
    
    private func handleStreamingAnswerChunk(_ chunk: String) {
        currentAnswerAccumulator += chunk
        let questionText = !currentSpokenQuestion.isEmpty ? currentSpokenQuestion : "Live Question"
        let fullAnswer = currentAnswerAccumulator
        
        Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
            if var current = AppState.shared.activeQA, current.status == .generating {
                current.answer = fullAnswer
                AppState.shared.activeQA = current
            } else {
                // If previous was completed, archive it
                if let previous = AppState.shared.activeQA, previous.status == .completed {
                    AppState.shared.dismissActiveQA()
                }
                let item = QAItem(
                    question: questionText,
                    answer: fullAnswer,
                    status: .generating
                )
                AppState.shared.activeQA = item
            }
        }
    }
    
    private func finalizeCurrentAnswer() {
        let finalAnswer = currentAnswerAccumulator
        currentAnswerAccumulator = ""
        
        guard !finalAnswer.isEmpty else { return }
        
        Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
            if var current = AppState.shared.activeQA {
                current.answer = finalAnswer
                current.status = .completed
                AppState.shared.activeQA = current
            }
        }
    }
    
    // MARK: - Auto-Reconnect
    
    private func handleConnectionFailure() {
        guard isRunning && !isReconnecting else { return }
        isReconnecting = true
        isSetupComplete = false
        
        reconnectAttempts += 1
        let backoff = min(8.0, Double(reconnectAttempts) * 1.5)
        
        Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
            AppState.shared.liveStreamingStatus = "Reconnecting in \(Int(backoff))s..."
        }
        
        queue.asyncAfter(deadline: .now() + backoff) { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.isReconnecting = false
            print("[GeminiLiveClient] Attempting auto-reconnect (\(self.reconnectAttempts))...")
            self.connectWebSocket()
        }
    }
    
    // MARK: - Optional Audio Playback
    
    private func setupAudioPlayer() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        
        // 24kHz 1-channel Float32 format for AVAudioEngine playback
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!
        self.audioOutputFormat = format
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        try? engine.start()
        player.play()
        
        self.audioEngine = engine
        self.audioPlayerNode = player
    }
    
    private func playAudioPcmData(_ pcm16Data: Data) {
        guard shouldSpeakAnswers else { return }
        guard let format = audioOutputFormat, let player = audioPlayerNode else { return }
        
        let sampleCount = pcm16Data.count / 2
        guard sampleCount > 0, let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(sampleCount)
        
        guard let channelData = pcmBuffer.floatChannelData?[0] else { return }
        pcm16Data.withUnsafeBytes { rawBuffer in
            let int16Ptr = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let val = Int16(littleEndian: int16Ptr[i])
                channelData[i] = Float(val) / 32767.0
            }
        }
        
        player.scheduleBuffer(pcmBuffer, at: nil, options: [], completionHandler: nil)
    }
    
    private func stopAudioPlayback() {
        audioPlayerNode?.stop()
        audioPlayerNode?.play()
    }
}
