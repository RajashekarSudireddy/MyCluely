import Foundation
import AVFoundation

public protocol MicrophoneCaptureDelegate: AnyObject {
    func didCaptureMicrophonePCM(_ buffer: AVAudioPCMBuffer)
    func microphoneCaptureDidFail(with error: Error)
}

public final class MicrophoneCapture: @unchecked Sendable {
    public weak var delegate: MicrophoneCaptureDelegate?
    private var audioEngine: AVAudioEngine?
    public private(set) var isRunning: Bool = false
    
    public init() {}
    
    public static func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    public func start() throws {
        guard !isRunning else { return }
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Ensure input format has valid channels and sample rate
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw NSError(domain: "MyCluely", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid microphone audio format."])
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.delegate?.didCaptureMicrophonePCM(buffer)
        }
        
        try engine.start()
        self.audioEngine = engine
        self.isRunning = true
    }
    
    public func stop() {
        guard isRunning, let engine = audioEngine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.audioEngine = nil
        self.isRunning = false
    }
}
