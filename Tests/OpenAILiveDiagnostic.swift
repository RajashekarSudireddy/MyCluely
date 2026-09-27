import Foundation

// Quick diagnostic script to inspect OpenAI Realtime WebSocket handshake & responses
let modelToTest = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "gpt-realtime"
guard ProcessInfo.processInfo.environment["MYCLUELY_RUN_LIVE_TESTS"] == "1",
      let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
    print("Set MYCLUELY_RUN_LIVE_TESTS=1 and OPENAI_API_KEY to run this network diagnostic.")
    exit(0)
}

print("==================================================")
print("🔍 Testing OpenAI Realtime WebSocket Handshake")
print("OpenAI Realtime diagnostic")
print("API key configured (value omitted)")
print("==================================================")

let urlString = "wss://api.openai.com/v1/realtime?model=\(modelToTest)"
guard let url = URL(string: urlString) else {
    print("Invalid diagnostic URL")
    exit(1)
}

var request = URLRequest(url: url)
request.timeoutInterval = 10.0
request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol `protocol`: String?) {
        print("WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket closed (code \(closeCode.rawValue))")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            print("Task failed (numeric code \(error.code); details omitted)")
            if let response = task.response as? HTTPURLResponse {
                print("   HTTP Status Code: \(response.statusCode)")
            }
        }
    }
}

let delegate = WebSocketDelegate()
let config = URLSessionConfiguration.ephemeral
let session = URLSession(configuration: config, delegate: delegate, delegateQueue: .main)
let task = session.webSocketTask(with: request)
task.resume()

func listen(task: URLSessionWebSocketTask) {
    task.receive { result in
        switch result {
        case .success(let message):
            switch message {
            case .string(let text):
                print("Text frame received (\(text.utf8.count) bytes; contents omitted)")
            case .data(let data):
                print("Binary frame received (\(data.count) bytes; contents omitted)")
            @unknown default:
                print("📩 [Unknown message received]")
            }
            listen(task: task)
        case .failure(let error as NSError):
            print("Receive failed (numeric code \(error.code); details omitted)")
        }
    }
}

listen(task: task)

RunLoop.main.run(until: Date().addingTimeInterval(5.0))
task.cancel(with: .normalClosure, reason: nil)
session.invalidateAndCancel()
print("Diagnostic finished.")
