import Foundation

public enum QAStatus: Equatable {
    case detecting
    case generating
    case completed
    case error(String)
}

public struct QAItem: Identifiable, Equatable {
    public let id: UUID
    public var question: String
    public var answer: String
    public let timestamp: Date
    public var status: QAStatus
    public var isExpanded: Bool
    
    public init(
        id: UUID = UUID(),
        question: String,
        answer: String = "",
        timestamp: Date = Date(),
        status: QAStatus = .detecting,
        isExpanded: Bool = true
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.timestamp = timestamp
        self.status = status
        self.isExpanded = isExpanded
    }
}
