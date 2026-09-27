import Foundation
import Speech
import AVFoundation

public final class SpeechTranscriber: @unchecked Sendable {
    public static let shared = SpeechTranscriber()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var questionDetector: QuestionDetector?
    
    private let queue = DispatchQueue(label: "com.mycluely.speechtranscriber")
    private var ownerSessionID: UUID?
    private var isRunning: Bool = false
    private var isRestarting: Bool = false
    
    private init() {}

    public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    public func start() {
        Task { @MainActor [self] in
            guard AuthManager.shared.isAuthenticated else { return }
            let sessionID = AuthManager.shared.sessionID
            let status = SFSpeechRecognizer.authorizationStatus() == .notDetermined
                ? await Self.requestAuthorization() : SFSpeechRecognizer.authorizationStatus()
            guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else { return }
            guard status == .authorized else {
                AppState.shared.permissionMessage = "Allow Speech Recognition in System Settings to use Local STT."
                return
            }
            self.queue.async { [weak self] in
                guard let self = self, !self.isRunning else { return }
                self.isRunning = true
                self.startRecognitionSession()
            }
        }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isRunning = false
            self.stopRecognitionSession()
            self.questionDetector?.reset()
        }
    }
    
    public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self = self, self.isRunning, !AudioManager.shared.isPaused else { return }
            self.recognitionRequest?.append(buffer)
        }
    }
    
    private func startRecognitionSession() {
        stopRecognitionSession()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            Task { @MainActor in
                AppState.shared.permissionMessage = "Speech recognizer is currently unavailable on this device."
            }
            return
        }
        
        guard recognizer.supportsOnDeviceRecognition else {
            Task { @MainActor in
                AppState.shared.permissionMessage = "On-device speech recognition is unavailable for this language. Select another supported language or choose Cloud Live mode."
            }
            return
        }
        let sessionID = DispatchQueue.main.sync { AuthManager.shared.sessionID }
        self.ownerSessionID = sessionID
        let detector = QuestionDetector()
        detector.onQuestionDetected = { [weak self] question in
            self?.handleQuestionDetected(question, sessionID: sessionID)
        }
        self.questionDetector = detector
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        
        self.recognitionRequest = request
        
        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self, self.isRunning, self.ownerSessionID == sessionID else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                
                Task { @MainActor in
                    guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else { return }
                    AppState.shared.liveTranscript = transcription
                }
                
                detector.processTranscript(transcription, isFinal: isFinal)
                
                if isFinal {
                    self.rolloverSession()
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                // Codes 203 or 216 mean speech was cancelled or ended normally
                if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 203 || nsError.code == 216) {
                    self.rolloverSession()
                } else if self.isRunning && !self.isRestarting {
                    print("[SpeechTranscriber] Recognition error (details omitted)")
                    self.rolloverSession()
                }
            }
        }
    }
    
    private func stopRecognitionSession() {
        ownerSessionID = nil
        questionDetector?.reset()
        questionDetector = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func rolloverSession() {
        guard isRunning && !isRestarting else { return }
        isRestarting = true
        
        queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.isRunning else {
                self?.isRestarting = false
                return
            }
            self.startRecognitionSession()
            self.isRestarting = false
        }
    }
    
    private func handleQuestionDetected(_ question: String, sessionID: UUID) {
        print("[SpeechTranscriber] Question detected")
        
        Task { @MainActor in
            guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else { return }
            let item = QAItem(question: question, answer: "", status: .generating)
            AppState.shared.activeQA = item
            
            if AppState.shared.autoAnswer {
                AnswerService.shared.generateAnswer(for: item)
            }
        }
    }
}
