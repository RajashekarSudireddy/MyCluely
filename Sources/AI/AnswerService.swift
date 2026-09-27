import Foundation

public final class AnswerService: @unchecked Sendable {
    public static let shared = AnswerService()
    
    private let session: URLSession
    
    // Priority order of reliable, ultra-low latency fallback models
    private let fallbackChain = [
        "gemini-2.5-flash",
        "gemini-3.8-flash",
        "gemini-flash-latest",
        "gemini-2.5-flash-lite"
    ]
    
    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25.0
        config.timeoutIntervalForResource = 35.0
        self.session = URLSession(configuration: config)
    }
    
    @MainActor
    public func generateAnswer(for item: QAItem) {
        guard AuthManager.shared.isAuthenticated else { return }
        let sessionID = AuthManager.shared.sessionID
        let key = AppState.shared.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredModel = AppState.shared.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            
            if key.isEmpty {
                await MainActor.run {
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else { return }
                    var updated = item
                    updated.answer = "💡 Question detected! Enter your Google Gemini API key in Settings (⚙️) to enable instant AI answers."
                    updated.status = .completed
                    AppState.shared.activeQA = updated
                }
                return
            }
            
            // Build list of models to try starting with user's preferred model
            var modelsToTry = [preferredModel.isEmpty ? "gemini-2.5-flash" : preferredModel]
            for fallback in fallbackChain where !modelsToTry.contains(fallback) {
                modelsToTry.append(fallback)
            }
            
            var capturedErrorMessage: String? = nil
            for model in modelsToTry {
                guard await MainActor.run(body: { AuthManager.shared.isAuthenticated && AuthManager.shared.sessionID == sessionID }) else { return }
                do {
                    let answerText = try await callGeminiAPI(question: item.question, apiKey: key, model: model)
                    
                    await MainActor.run {
                        guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else { return }
                        var updated = item
                        updated.answer = answerText
                        updated.status = .completed
                        AppState.shared.activeQA = updated
                    }
                    return
                } catch {
                    capturedErrorMessage = "Provider request failed. Check your key, model, and network connection."
                    print("[AnswerService] Request failed; trying fallback (details omitted)")
                    continue
                }
            }
            
            // If all models in the chain failed
            let finalErrorMessage = capturedErrorMessage ?? "Request timed out."
            await MainActor.run {
                guard AuthManager.shared.isAuthenticated, AuthManager.shared.sessionID == sessionID else { return }
                var updated = item
                updated.answer = "Unable to fetch answer: \(finalErrorMessage)"
                updated.status = .error(finalErrorMessage)
                AppState.shared.activeQA = updated
            }
        }
    }
    
    private func callGeminiAPI(question: String, apiKey: String, model: String) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "MyCluely", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint URL."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 20.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = "You are a concise, ultra-fast HUD assistant. The user is in a live meeting or listening to audio where a question was asked. Provide a direct, factual answer in 1 to 3 short sentences or bullet points. Maximum 60 words. No greetings, no preamble."
        
        var generationConfig: [String: Any] = [
            "temperature": 0.2,
            "maxOutputTokens": 256
        ]
        
        // Disable unnecessary thinking tokens on models that support thinkingConfig for instant response
        if model.contains("2.5-flash") || model.contains("3.8-flash") {
            generationConfig["thinkingConfig"] = ["thinkingBudget": 0]
        }
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "Answer this question directly and concisely: \(question)"]
                    ]
                ]
            ],
            "systemInstruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "generationConfig": generationConfig
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode) error."])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw NSError(domain: "GeminiAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format."])
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
