import Foundation
import AVFoundation
import AppKit

public final class OpenAILiveClient: @unchecked Sendable {
    public static let shared = OpenAILiveClient()
    
    private let queue = DispatchQueue(label: "com.mycluely.openailive", qos: .userInitiated)
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var ownerSessionID: UUID?
    private var isRunning: Bool = false
    private var isSessionConfigured: Bool = false
    private var isReconnecting: Bool = false
    private var reconnectAttempts: Int = 0
    private var currentModel: String = "gpt-realtime"
    
    // Accumulation buffer for 24kHz 16-bit PCM audio (chunked every ~100ms = 4800 bytes)
    // 2400 samples * 2 bytes = 4800 bytes per 100ms at 24kHz
    private var pendingAudioData = Data()
    private let targetChunkSizeBytes = 4800
    
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
            self.isSessionConfigured = false
            self.disconnectWebSocket()
            self.pendingAudioData.removeAll()
            self.currentSpokenQuestion = ""
            self.currentAnswerAccumulator = ""
            self.wasPaused = false
            self.stopAudioPlayback()
            
            Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                if AppState.shared.aiProvider == .openAI {
                    AppState.shared.liveStreamingStatus = "Inactive"
                }
            }
        }
    }
    
    public func restart() {
        stop()
        queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.start()
        }
    }
    
    // MARK: - Audio Ingestion & 16kHz -> 24kHz Resampling
    
    public func appendAudioBuffer(_ pcmBuffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            let isPaused = AudioManager.shared.isPaused
            if isPaused {
                if !self.wasPaused {
                    self.wasPaused = true
                    self.sendAudioClear()
                }
                return
            } else if self.wasPaused {
                self.wasPaused = false
            }
            
            let frameCount = Int(pcmBuffer.frameLength)
            guard frameCount > 0, let floatChannel = pcmBuffer.floatChannelData?[0] else { return }
            
            // Resample from 16kHz to 24kHz (1.5x output samples) using linear interpolation
            let outputSampleCount = Int(Double(frameCount) * 1.5)
            var pcm16Data = Data(capacity: outputSampleCount * 2)
            
            for j in 0..<outputSampleCount {
                let pos = Double(j) * (2.0 / 3.0)
                let idx0 = min(Int(pos), frameCount - 1)
                let idx1 = min(idx0 + 1, frameCount - 1)
                let alpha = Float(pos - Double(idx0))
                
                let s0 = floatChannel[idx0]
                let s1 = floatChannel[idx1]
                let sample = (1.0 - alpha) * s0 + alpha * s1
                let clamped = max(-1.0, min(1.0, sample))
                
                var int16Sample = Int16(clamped * 32767.0).littleEndian
                withUnsafeBytes(of: &int16Sample) { bytes in
                    pcm16Data.append(contentsOf: bytes)
                }
            }
            
            self.pendingAudioData.append(pcm16Data)
            
            // Only stream if session setup has completed on server
            guard self.isSessionConfigured, self.webSocketTask != nil else {
                // Keep last 1 second of audio (48,000 bytes) in buffer while connecting
                if self.pendingAudioData.count > 48000 {
                    self.pendingAudioData = Data(self.pendingAudioData.suffix(48000))
                }
                return
            }
            
            self.flushPendingAudio()
        }
    }
    
    private func flushPendingAudio() {
        while self.pendingAudioData.count >= self.targetChunkSizeBytes {
            let chunk = self.pendingAudioData.prefix(self.targetChunkSizeBytes)
            self.pendingAudioData.removeFirst(self.targetChunkSizeBytes)
            self.sendAudioChunk(Data(chunk))
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
                AppState.shared.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            apiKey = DispatchQueue.main.sync {
                AppState.shared.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if apiKey.isEmpty {
            Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                AppState.shared.liveStreamingStatus = "OpenAI API Key Required"
                AppState.shared.permissionMessage = "Enter your OpenAI API key in Settings to enable OpenAI Realtime (gpt-realtime) streaming."
            }
            return
        }
        
        var model = "gpt-realtime"
        if Thread.isMainThread {
            model = MainActor.assumeIsolated {
                AppState.shared.openAIModelName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            model = DispatchQueue.main.sync {
                AppState.shared.openAIModelName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if model.isEmpty || model.contains("gpt-live") || model.contains("gpt-4o-realtime-preview") {
            model = "gpt-realtime"
        }
        self.currentModel = model
        
        Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
            AppState.shared.liveStreamingStatus = "Connecting to OpenAI Realtime..."
        }
        
        let urlString = "wss://api.openai.com/v1/realtime?model=\(model)"
        guard let url = URL(string: urlString) else {
            print("[OpenAILiveClient] Invalid WebSocket URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // Note: OpenAI GA Realtime API does NOT use the deprecated "OpenAI-Beta: realtime=v1" header
        
        let config = URLSessionConfiguration.ephemeral
        self.session = URLSession(configuration: config)
        let task = session!.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()
        
        print("[OpenAILiveClient] WebSocket connecting to OpenAI Realtime...")
        listenForMessages()
    }
    
    private func disconnectWebSocket() {
        isSessionConfigured = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
    }
    
    // MARK: - Protocol Messages (Sent strictly as UTF-8 text frames)
    
    private func sendSessionUpdate() {
        let sessionPayload: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "instructions": "You are MyCluely, an ultra-fast real-time speech assistant and co-pilot. You listen continuously to live audio stream from meetings, discussions, and conversations. When anyone asks a question, makes an inquiry, or requests information, formulate a concise, direct, accurate answer immediately. State the answer in 1 to 2 clear sentences or compact bullet points (maximum 50 words). No pleasantries, no greetings, no introductory filler. If people are just chatting or discussing without asking a question, remain completely silent.",
                "output_modalities": ["audio"],
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "transcription": [
                            "model": "whisper-1"
                        ],
                        "turn_detection": [
                            "type": "server_vad",
                            "threshold": 0.5,
                            "prefix_padding_ms": 300,
                            "silence_duration_ms": 500,
                            "create_response": true,
                            "interrupt_response": true
                        ]
                    ],
                    "output": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "voice": "alloy"
                    ]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: sessionPayload, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(jsonString)) { [weak self] error in
            if error != nil {
                print("[OpenAILiveClient] Session update send error (details omitted)")
                self?.handleConnectionFailure()
            } else {
                print("[OpenAILiveClient] GA session.update text message sent to OpenAI Realtime API")
            }
        }
    }
    
    private func sendAudioChunk(_ pcmData: Data) {
        let base64String = pcmData.base64EncodedString()
        let audioMessage: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64String
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: audioMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(jsonString)) { [weak self] error in
            if error != nil {
                print("[OpenAILiveClient] Audio chunk send error (details omitted)")
                self?.handleConnectionFailure()
            }
        }
    }
    
    private func sendAudioClear() {
        let clearMessage: [String: Any] = [
            "type": "input_audio_buffer.clear"
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: clearMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        webSocketTask?.send(.string(jsonString)) { _ in }
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
                    print("[OpenAILiveClient] WebSocket receive failed (details omitted)")
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
        
        guard let type = json["type"] as? String else { return }
        
        switch type {
        case "session.created":
            print("[OpenAILiveClient] session.created received from OpenAI Realtime.")
            sendSessionUpdate()
            
        case "session.updated":
            print("[OpenAILiveClient] Session active")
            isSessionConfigured = true
            reconnectAttempts = 0
            flushPendingAudio()
            Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                if AppState.shared.aiProvider == .openAI {
                    AppState.shared.liveStreamingStatus = "OpenAI Realtime (\(self.currentModel)) Active"
                    AppState.shared.permissionMessage = nil
                }
            }
            
        case "conversation.item.input_audio_transcription.completed":
            var extractedTranscript: String?
            if let transcript = json["transcript"] as? String {
                extractedTranscript = transcript
            } else if let item = json["item"] as? [String: Any],
                      let content = item["content"] as? [[String: Any]],
                      let first = content.first,
                      let t = first["transcript"] as? String {
                extractedTranscript = t
            }
            
            if let transcript = extractedTranscript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                self.currentSpokenQuestion = cleaned
                Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                    AppState.shared.liveTranscript = cleaned
                    // Update active question title if it's currently generating or was a placeholder
                    if var current = AppState.shared.activeQA {
                        if current.question == "Live Question" || current.status == .generating {
                            current.question = cleaned
                            AppState.shared.activeQA = current
                        }
                    }
                }
            }
            
        case "response.output_audio_transcript.delta", "response.audio_transcript.delta":
            if let delta = json["delta"] as? String, !delta.isEmpty {
                handleStreamingAnswerChunk(delta)
            }
            
        case "response.output_text.delta", "response.text.delta":
            if let delta = json["delta"] as? String, !delta.isEmpty {
                handleStreamingAnswerChunk(delta)
            }
            
        case "response.output_audio.delta", "response.audio.delta":
            if let base64 = json["delta"] as? String,
               let pcmData = Data(base64Encoded: base64) {
                playAudioPcmData(pcmData)
            }
            
        case "input_audio_buffer.speech_started":
            print("[OpenAILiveClient] User speech started - stopping speech playback")
            stopAudioPlayback()
            
        case "response.created":
            // Reset answer accumulator for the new response turn
            currentAnswerAccumulator = ""
            
        case "response.done":
            // If delta accumulation missed the transcript, extract from response.output
            if currentAnswerAccumulator.isEmpty,
               let resp = json["response"] as? [String: Any],
               let output = resp["output"] as? [[String: Any]],
               let firstOut = output.first,
               let content = firstOut["content"] as? [[String: Any]],
               let firstContent = content.first,
               let transcript = firstContent["transcript"] as? String,
               !transcript.isEmpty {
                currentAnswerAccumulator = transcript
            }
            finalizeCurrentAnswer()
            
        case "error":
            print("[OpenAILiveClient] Provider returned an error (details omitted)")
            Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
                if AppState.shared.aiProvider == .openAI {
                    AppState.shared.liveStreamingStatus = "OpenAI request failed"
                    AppState.shared.permissionMessage = "Check your OpenAI key, quota, model, and network connection."
                }
            }

        default:
            break
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
        isSessionConfigured = false
        
        reconnectAttempts += 1
        let backoff = min(8.0, Double(reconnectAttempts) * 1.5)
        
        Task { @MainActor [owner = self.ownerSessionID] in
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == owner else { return }
            if AppState.shared.aiProvider == .openAI {
                AppState.shared.liveStreamingStatus = "Reconnecting in \(Int(backoff))s..."
            }
        }
        
        queue.asyncAfter(deadline: .now() + backoff) { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.isReconnecting = false
            print("[OpenAILiveClient] Attempting auto-reconnect (\(self.reconnectAttempts))...")
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
