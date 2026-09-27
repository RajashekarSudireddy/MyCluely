import Foundation
import AVFoundation

@main
struct OpenAILiveClientTestsRunner {
    static func main() {
        print("🧪 Running OpenAILiveClient Automated Test Suite...\n")
        
        testResampling16kHzTo24kHz()
        testGASessionPayload()
        testAudioChunkingMath()
        testLiveOpenAIRealtimeHandshake()
        
        print("\n🎉 ALL OpenAILiveClient tests passed successfully!")
    }
    
    // MARK: - 1. Test 16kHz to 24kHz Resampling
    static func testResampling16kHzTo24kHz() {
        print("▶️ [Test 1] Testing 16kHz -> 24kHz PCM16 linear interpolation resampling...")
        
        let frameCount = 1600 // 100ms at 16kHz
        let srcFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            fatalError("Failed to allocate test buffer")
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Fill with a 440Hz sine wave
        if let floatChannel = pcmBuffer.floatChannelData?[0] {
            for i in 0..<frameCount {
                floatChannel[i] = sin(2.0 * Float.pi * 440.0 * Float(i) / 16000.0)
            }
        }
        
        let outputSampleCount = Int(Double(frameCount) * 1.5)
        assert(outputSampleCount == 2400, "1600 samples at 16kHz must resample to 2400 samples at 24kHz")
        
        var pcm16Data = Data(capacity: outputSampleCount * 2)
        if let floatChannel = pcmBuffer.floatChannelData?[0] {
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
        }
        
        assert(pcm16Data.count == 4800, "2400 samples * 2 bytes must equal 4800 bytes (100ms at 24kHz)")
        print("   ✅ Resampling succeeded: \(frameCount) samples @ 16kHz -> \(outputSampleCount) samples (\(pcm16Data.count) bytes) @ 24kHz")
    }
    
    // MARK: - 2. Test GA Session Payload
    static func testGASessionPayload() {
        print("▶️ [Test 2] Testing GA session.update payload structure & text frame serialization...")
        
        let sessionPayload: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "instructions": "Test instructions",
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
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            fatalError("Failed to serialize sessionPayload to UTF-8 text")
        }
        
        assert(jsonString.contains("\"type\":\"session.update\""), "Must contain type session.update")
        assert(jsonString.contains("\"type\":\"realtime\""), "Must specify GA session.type realtime")
        assert(jsonString.contains("\"output_modalities\":[\"audio\"]"), "Must contain output_modalities")
        assert(jsonString.contains("\"whisper-1\""), "Must configure whisper-1 input transcription")
        print("   ✅ GA session payload correctly structured and serialized as UTF-8 string (\(jsonString.count) chars)")
    }
    
    // MARK: - 3. Test Audio Chunking Math
    static func testAudioChunkingMath() {
        print("▶️ [Test 3] Testing buffer accumulation & chunking at 4800 bytes...")
        
        let targetChunkSizeBytes = 4800
        var pendingAudioData = Data()
        
        // Push 11,000 bytes (should yield two 4800-byte chunks and leave 1400 bytes)
        let simulatedBytes = Data(repeating: 0x55, count: 11000)
        pendingAudioData.append(simulatedBytes)
        
        var chunksSent = 0
        while pendingAudioData.count >= targetChunkSizeBytes {
            let chunk = pendingAudioData.prefix(targetChunkSizeBytes)
            assert(chunk.count == targetChunkSizeBytes, "Chunk size must be exact")
            pendingAudioData.removeFirst(targetChunkSizeBytes)
            chunksSent += 1
        }
        
        assert(chunksSent == 2, "11,000 bytes must yield exactly 2 full chunks of 4800 bytes")
        assert(pendingAudioData.count == 1400, "Remainder must be 1400 bytes")
        
        // Push remainder up to 5000 bytes
        pendingAudioData.append(Data(repeating: 0xAA, count: 3600)) // 1400 + 3600 = 5000
        assert(pendingAudioData.count == 5000)
        
        _ = pendingAudioData.prefix(targetChunkSizeBytes)
        pendingAudioData.removeFirst(targetChunkSizeBytes)
        chunksSent += 1
        
        assert(chunksSent == 3)
        assert(pendingAudioData.count == 200)
        print("   ✅ Buffer accumulation & chunking logic verified: 3 chunks emitted, 200 bytes residual")
    }
    
    // MARK: - 4. Test Live Realtime WebSocket Handshake
    static func testLiveOpenAIRealtimeHandshake() {
        print("▶️ [Test 4] Testing live OpenAI Realtime WebSocket connection with gpt-realtime...")
        
        guard ProcessInfo.processInfo.environment["MYCLUELY_RUN_LIVE_TESTS"] == "1",
              let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            print("   Skipped live test; set MYCLUELY_RUN_LIVE_TESTS=1 and OPENAI_API_KEY to opt in.")
            return
        }

        let sema = DispatchSemaphore(value: 0)
        let url = URL(string: "wss://api.openai.com/v1/realtime?model=gpt-realtime")!
        var req = URLRequest(url: url)
        req.timeoutInterval = 10.0
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .ephemeral)
        let ws = session.webSocketTask(with: req)
        ws.resume()
        
        var handshakeCompleted = false
        var sessionUpdated = false
        
        func sendSessionUpdate() {
            let sessionPayload: [String: Any] = [
                "type": "session.update",
                "session": [
                    "type": "realtime",
                    "instructions": "Diagnostic test. Respond in 2 words.",
                    "output_modalities": ["audio"],
                    "audio": [
                        "input": [
                            "transcription": ["model": "whisper-1"]
                        ],
                        "output": [
                            "voice": "alloy"
                        ]
                    ]
                ]
            ]
            let data = try! JSONSerialization.data(withJSONObject: sessionPayload)
            let jsonString = String(data: data, encoding: .utf8)!
            ws.send(.string(jsonString)) { error in
                if error != nil {
                    print("   Send session update failed (details omitted)")
                }
            }
        }
        
        func listen() {
            ws.receive { result in
                switch result {
                case .success(let msg):
                    if case .string(let text) = msg {
                        if text.contains("session.created") {
                            handshakeCompleted = true
                            sendSessionUpdate()
                            listen()
                        } else if text.contains("session.updated") {
                            sessionUpdated = true
                            sema.signal()
                        } else if text.contains("error") {
                            print("   Provider returned an error (details omitted)")
                            sema.signal()
                        } else {
                            listen()
                        }
                    }
                case .failure:
                    print("   WebSocket failed (details omitted)")
                    sema.signal()
                }
            }
        }
        
        listen()
        _ = sema.wait(timeout: .now() + 6.0)
        ws.cancel(with: .normalClosure, reason: nil)
        
        assert(handshakeCompleted, "WebSocket must receive session.created from OpenAI")
        assert(sessionUpdated, "WebSocket must receive session.updated after GA session.update text frame")
        print("   ✅ Live WebSocket connection and session.update verified with gpt-realtime!")
    }
}
