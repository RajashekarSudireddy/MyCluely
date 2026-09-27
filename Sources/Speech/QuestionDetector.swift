import Foundation

public final class QuestionDetector: @unchecked Sendable {
    private var debounceTimer: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.mycluely.questiondetector")
    private var lastCandidateQuestion: String?
    private var recentQuestions: Set<String> = []
    
    public var onQuestionDetected: ((String) -> Void)?
    
    private let interrogativeStarters: Set<String> = [
        "what", "why", "how", "who", "when", "where", "which", "whose", "whom",
        "can", "could", "would", "will", "should", "is", "are", "am", "was", "were",
        "do", "does", "did", "have", "has", "had", "may", "might"
    ]
    
    public init() {}
    
    public func processTranscript(_ text: String, isFinal: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            // Extract the most recent candidate sentence
            let candidate = self.extractLastSentence(from: trimmed)
            
            if self.isQuestion(candidate, fullText: trimmed) {
                if isFinal {
                    self.triggerQuestion(candidate)
                } else {
                    self.scheduleDebounce(for: candidate)
                }
            }
        }
    }
    
    private func extractLastSentence(from text: String) -> String {
        let separators = CharacterSet(charactersIn: ".?!;\n")
        let sentences = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return sentences.last ?? text
    }
    
    private func isQuestion(_ sentence: String, fullText: String) -> Bool {
        let clean = sentence.trimmingCharacters(in: CharacterSet(charactersIn: "\"\'` "))
        let words = clean.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // Exclude ultra-short interjections like "what?", "really?"
        guard words.count >= 3 else { return false }
        
        // 1. Check for explicit question mark in sentence or trailing full text
        if sentence.contains("?") || (fullText.hasSuffix("?") && words.count >= 3) {
            return true
        }
        
        // 2. Check interrogative starters
        if let first = words.first, interrogativeStarters.contains(first) {
            return true
        }
        
        // 3. Conversational phrases
        let lower = clean.lowercased()
        if lower.contains("can you") ||
           lower.contains("could you") ||
           lower.contains("how do i") ||
           lower.contains("how does") ||
           lower.contains("what does") ||
           lower.contains("what is") ||
           lower.contains("tell me about") ||
           lower.contains("do you know") {
            return true
        }
        
        return false
    }
    
    private func scheduleDebounce(for question: String) {
        debounceTimer?.cancel()
        lastCandidateQuestion = question
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let q = self.lastCandidateQuestion else { return }
            self.triggerQuestion(q)
        }
        debounceTimer = workItem
        
        // Wait 1.1s of silence before finalizing question
        queue.asyncAfter(deadline: .now() + 1.1, execute: workItem)
    }
    
    private func triggerQuestion(_ question: String) {
        debounceTimer?.cancel()
        debounceTimer = nil
        lastCandidateQuestion = nil
        
        let normalized = question.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
        
        guard !normalized.isEmpty else { return }
        guard !recentQuestions.contains(normalized) else { return }
        
        recentQuestions.insert(normalized)
        
        // Expire from deduplication set after 20 seconds
        queue.asyncAfter(deadline: .now() + 20.0) { [weak self] in
            self?.recentQuestions.remove(normalized)
        }
        
        let formatted = question.hasSuffix("?") ? question : "\(question)?"
        
        DispatchQueue.main.async { [weak self] in
            self?.onQuestionDetected?(formatted)
        }
    }
    
    public func reset() {
        queue.async { [weak self] in
            self?.debounceTimer?.cancel()
            self?.debounceTimer = nil
            self?.lastCandidateQuestion = nil
            self?.recentQuestions.removeAll()
        }
    }
}
