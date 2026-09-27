import Foundation
import ScreenCaptureKit
import CoreMedia

public protocol SystemAudioCaptureDelegate: AnyObject {
    func didCaptureAudioSample(_ sampleBuffer: CMSampleBuffer)
    func systemAudioCaptureDidFail(with error: Error)
}

public final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    public weak var delegate: SystemAudioCaptureDelegate?
    
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.mycluely.systemaudio", qos: .userInteractive)
    public private(set) var isRunning: Bool = false
    
    public override init() {
        super.init()
    }
    
    public static func hasScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    public static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }
    
    public func start() async throws {
        guard !isRunning else { return }
        
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "MyCluely", code: 1, userInfo: [NSLocalizedDescriptionKey: "No screen display found to capture system audio."])
        }
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 16000
        config.channelCount = 1
        config.excludesCurrentProcessAudio = true
        
        // Minimal video resolution to consume practically zero CPU/GPU resources
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        
        try await newStream.startCapture()
        self.stream = newStream
        self.isRunning = true
    }
    
    public func stop() async {
        guard isRunning, let stream = stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            print("[SystemAudioCapture] Error stopping stream (details omitted)")
        }
        self.stream = nil
        self.isRunning = false
    }
    
    // MARK: - SCStreamOutput
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        delegate?.didCaptureAudioSample(sampleBuffer)
    }
    
    // MARK: - SCStreamDelegate
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("[SystemAudioCapture] Stream stopped with error (details omitted)")
        self.isRunning = false
        delegate?.systemAudioCaptureDidFail(with: error)
    }
}
