import Foundation
import AVFoundation
import CoreMedia

public final class AudioBufferConverter {
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private var lastInputFormat: AVAudioFormat?
    
    public init() {
        // Standard speech recognition format: 16 kHz, 1 channel (mono), Float32
        self.targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    }
    
    public func convert(sampleBuffer: CMSampleBuffer) -> (buffer: AVAudioPCMBuffer, level: Float)? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            return nil
        }
        
        guard let inputFormat = AVAudioFormat(streamDescription: asbd) else {
            return nil
        }
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return nil }
        
        guard let inputPCM = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        inputPCM.frameLength = AVAudioFrameCount(frameCount)
        
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: inputPCM.mutableAudioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return nil }
        
        return convertPCM(inputPCM: inputPCM)
    }
    
    public func convertPCM(inputPCM: AVAudioPCMBuffer) -> (buffer: AVAudioPCMBuffer, level: Float)? {
        let frameCount = inputPCM.frameLength
        guard frameCount > 0 else { return nil }
        
        // Calculate audio RMS level for visualizer
        var rms: Float = 0.0
        if let floatData = inputPCM.floatChannelData?[0] {
            var sum: Float = 0
            let strideStep = max(1, Int(frameCount) / 100)
            var count = 0
            for i in stride(from: 0, through: Int(frameCount) - 1, by: strideStep) {
                let val = floatData[i]
                sum += val * val
                count += 1
            }
            if count > 0 {
                rms = min(1.0, sqrt(sum / Float(count)) * 5.0)
            }
        }
        
        let inputFormat = inputPCM.format
        if inputFormat == targetFormat {
            return (inputPCM, rms)
        }
        
        if converter == nil || lastInputFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            lastInputFormat = inputFormat
        }
        
        guard let converter = converter else { return (inputPCM, rms) }
        
        let ratio = Double(targetFormat.sampleRate) / Double(inputFormat.sampleRate)
        let targetCapacity = AVAudioFrameCount(Double(frameCount) * ratio + 10)
        guard let outputPCM = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetCapacity) else {
            return (inputPCM, rms)
        }
        
        var error: NSError?
        var inputProvided = false
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            if !inputProvided {
                inputProvided = true
                outStatus.pointee = .haveData
                return inputPCM
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
        let convStatus = converter.convert(to: outputPCM, error: &error, withInputFrom: inputBlock)
        if convStatus == .error || error != nil {
            return (inputPCM, rms)
        }
        
        return (outputPCM, rms)
    }
}
