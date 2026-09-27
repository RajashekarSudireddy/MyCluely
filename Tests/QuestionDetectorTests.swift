import Foundation

@main
struct QuestionDetectorTestsRunner {
    static func main() {
        print("🧪 Running QuestionDetector Automated Test Suite...")
        
        let detector = QuestionDetector()
        var detectedQuestions: [String] = []
        
        detector.onQuestionDetected = { q in
            detectedQuestions.append(q)
        }
        
        // Test 1: Direct question with question mark
        detector.processTranscript("What is the difference between TCP and UDP?", isFinal: true)
        
        // Test 2: Plain statement (Should NOT trigger)
        detector.processTranscript("Today is a sunny day in San Francisco.", isFinal: true)
        
        // Test 3: Question without question mark
        detector.processTranscript("Can you explain how concurrency works in Swift", isFinal: true)
        
        // Test 4: Short word interjection (Should NOT trigger)
        detector.processTranscript("What?", isFinal: true)
        detector.processTranscript("Why?", isFinal: true)
        
        // Test 5: Multi-sentence containing question
        detector.processTranscript("The previous deployment failed. How do we roll it back?", isFinal: true)
        
        // Test 6: Deduplication test (Re-asking same question within window should NOT trigger duplicate)
        detector.processTranscript("What is the difference between TCP and UDP?", isFinal: true)
        
        // Run runloop to let async callbacks complete
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        
        print("📊 Detected Questions Count: \(detectedQuestions.count)")
        for (i, q) in detectedQuestions.enumerated() {
            print("   [\(i + 1)] \(q)")
        }
        
        assert(detectedQuestions.count == 3, "Expected exactly 3 questions detected, got \(detectedQuestions.count)")
        assert(detectedQuestions[0].contains("TCP and UDP"), "Expected Test 1 question")
        assert(detectedQuestions[1].contains("concurrency works in Swift"), "Expected Test 3 question")
        assert(detectedQuestions[2].contains("roll it back"), "Expected Test 5 question")
        
        print("✅ All QuestionDetector tests passed successfully!")
    }
}
