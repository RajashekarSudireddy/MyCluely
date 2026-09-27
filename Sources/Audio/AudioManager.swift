import Foundation
import AVFoundation
import CoreMedia

public final class AudioManager: SystemAudioCaptureDelegate, MicrophoneCaptureDelegate, @unchecked Sendable {
    public static let shared = AudioManager()
    
    private let systemCapture = SystemAudioCapture()
    private let micCapture = MicrophoneCapture()
    private let converter = AudioBufferConverter()
    
    // Thread-safe pause flag accessed by real-time audio threads
    private let lock = NSLock()
    private var _isPaused: Bool = false
    
    public var isPaused: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isPaused
        }
        set {
            lock.lock()
            _isPaused = newValue
            lock.unlock()
        }
    }
    
    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    private init() {
        systemCapture.delegate = self
        micCapture.delegate = self
    }
    
    public func start(source: AudioSourceType) async throws {
        await stop()
        
        switch source {
        case .systemAudio:
            try await systemCapture.start()
        case .microphone:
            try micCapture.start()
        case .both:
            try await systemCapture.start()
            try micCapture.start()
        }
        
        await MainActor.run {
            AppState.shared.isListening = true
            AppState.shared.audioSource = source
            AppState.shared.permissionMessage = nil // Cleared upon successful start
        }
    }
    
    public func stop() async {
        await systemCapture.stop()
        micCapture.stop()
        
        await MainActor.run {
            AppState.shared.isListening = false
            AppState.shared.audioLevel = 0.0
        }
    }
    
    public func switchSource(to source: AudioSourceType) async throws {
        let isListening = await AppState.shared.isListening
        if isListening {
            try await start(source: source)
        } else {
            await MainActor.run {
                AppState.shared.audioSource = source
                AppState.shared.permissionMessage = nil
            }
        }
    }
    
    // MARK: - SystemAudioCaptureDelegate
    public func didCaptureAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard !isPaused else { return }
        guard let (pcmBuffer, level) = converter.convert(sampleBuffer: sampleBuffer) else { return }
        
        Task { @MainActor in
            AppState.shared.audioLevel = level
            if AppState.shared.permissionMessage != nil {
                AppState.shared.permissionMessage = nil
            }
        }
        onAudioBuffer?(pcmBuffer)
    }
    
    public func systemAudioCaptureDidFail(with error: Error) {
        Task { @MainActor in
            AppState.shared.permissionMessage = "Permission needed: Enable MyCluely in System Settings > Privacy & Security > Screen & System Audio Recording."
        }
    }
    
    // MARK: - MicrophoneCaptureDelegate
    public func didCaptureMicrophonePCM(_ buffer: AVAudioPCMBuffer) {
        guard !isPaused else { return }
        guard let (pcmBuffer, level) = converter.convertPCM(inputPCM: buffer) else { return }
        
        Task { @MainActor in
            AppState.shared.audioLevel = max(AppState.shared.audioLevel, level)
            if AppState.shared.permissionMessage != nil {
                AppState.shared.permissionMessage = nil
            }
        }
        onAudioBuffer?(pcmBuffer)
    }
    
    public func microphoneCaptureDidFail(with error: Error) {
        Task { @MainActor in
            AppState.shared.permissionMessage = "Microphone capture error: \(error.localizedDescription)"
        }
    }
}
