import SwiftUI
import AppKit

public struct QuestionAnswerCard: View {
    public let item: QAItem
    public let onDismiss: () -> Void
    public let onRegenerate: () -> Void
    
    @State private var copied: Bool = false
    
    public init(item: QAItem, onDismiss: @escaping () -> Void, onRegenerate: @escaping () -> Void) {
        self.item = item
        self.onDismiss = onDismiss
        self.onRegenerate = onRegenerate
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with Question and Actions
            HStack(alignment: .top, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(Theme.questionColor)
                        .font(.system(size: 13))
                    
                    Text(item.question)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 8)
                
                HStack(spacing: 6) {
                    if !item.answer.isEmpty {
                        Button(action: copyToClipboard) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(copied ? .green : .secondary)
                                .frame(width: 20, height: 20)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Copy answer to clipboard")
                    }
                    
                    Button(action: onRegenerate) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Regenerate answer")
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
            }
            
            Divider()
                .opacity(0.3)
            
            // Answer Content / Streaming State
            switch item.status {
            case .detecting:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Detecting question context...")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 3)
                
            case .generating:
                if !item.answer.isEmpty {
                    // Streaming live answer
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Theme.answerColor)
                            .font(.system(size: 12))
                            .padding(.top, 2)
                        
                        Text(item.answer)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text("Streaming answer from Gemini Live...")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
                
            case .completed:
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.answerColor)
                        .font(.system(size: 12))
                        .padding(.top, 2)
                    
                    Text(item.answer)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                
            case .error(let errorMsg):
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    
                    Text(item.answer.isEmpty ? errorMsg : item.answer)
                        .font(.system(size: 11.5))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.innerCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.innerCornerRadius)
                .stroke(item.status == .generating ? Theme.answerColor.opacity(0.4) : Theme.questionColor.opacity(0.25), lineWidth: 1)
        )
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.answer, forType: .string)
        withAnimation(.spring()) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring()) {
                copied = false
            }
        }
    }
}
