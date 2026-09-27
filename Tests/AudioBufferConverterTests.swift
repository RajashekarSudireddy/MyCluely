import Foundation
import AVFoundation

@main
struct AudioBufferConverterTestsRunner {
    static func main() {
        print("🧪 Running AudioBufferConverter Automated Test Suite...")
        
        let converter = AudioBufferConverter()
        
        // Create 48kHz stereo mock PCM buffer
        let srcFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)!
        let frameCount: AVAudioFrameCount = 4800 // 100ms of audio
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount) else {
            fatalError("Failed to allocate test PCM buffer")
        }
        pcmBuffer.frameLength = frameCount
        
        // Fill with 440Hz sine wave tone
        if let channels = pcmBuffer.floatChannelData {
            for i in 0..<Int(frameCount) {
                let sample = sin(2.0 * Float.pi * 440.0 * Float(i) / 48000.0) * 0.5
                channels[0][i] = sample
                channels[1][i] = sample
            }
        }
        
        // Convert
        guard let (converted, level) = converter.convertPCM(inputPCM: pcmBuffer) else {
            fatalError("Failed to convert PCM buffer")
        }
        
        print("📊 Converted sample rate: \(converted.format.sampleRate) Hz (Expected: 16000.0)")
        print("📊 Converted channels: \(converted.format.channelCount) (Expected: 1)")
        print("📊 Converted frame length: \(converted.frameLength) (Expected: ~1600)")
        print("📊 Audio RMS level: \(level) (Expected: > 0.0)")
        
        assert(converted.format.sampleRate == 16000.0, "Sample rate must be 16kHz")
        assert(converted.format.channelCount == 1, "Channel count must be mono (1)")
        assert(level > 0.1, "RMS audio level must detect active tone")
        
        print("✅ All AudioBufferConverter tests passed successfully!")
    }
}
