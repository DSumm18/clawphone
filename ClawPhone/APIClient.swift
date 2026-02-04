import Foundation

// MARK: - API Client
class APIClient {
    static let shared = APIClient()
    
    // Direct server - no Vercel middleman
    private let baseURL = "http://142.132.160.28:8080/api"
    
    private init() {}
    
    // MARK: - Send Message
    func sendMessage(_ text: String, userId: String) async throws -> MessageResponse {
        guard let url = URL(string: "\(baseURL)/message") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "userId": userId,
            "message": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return MessageResponse(
            success: json["success"] as? Bool ?? false,
            messageId: json["messageId"] as? String,
            responseId: json["responseId"] as? String,
            source: json["source"] as? String ?? "unknown"
        )
    }
    
    // MARK: - Poll Messages
    func fetchMessages(userId: String, since: String) async throws -> [ServerMessage] {
        guard let url = URL(string: "\(baseURL)/messages?userId=\(userId)&since=\(since)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let messagesArray = json["messages"] as? [[String: Any]] ?? []
        
        return messagesArray.compactMap { msg in
            guard let id = msg["id"] as? String,
                  let text = msg["text"] as? String,
                  let from = msg["from"] as? String else { return nil }
            return ServerMessage(id: id, text: text, from: from)
        }
    }
    
    // MARK: - Get TTS Audio (Fish Audio)
    func fetchTTSAudio(text: String, voice: String) async throws -> Data? {
        guard let url = URL(string: "\(baseURL)/tts") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "text": text,
            "voice": voice
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        guard let audioUrlString = json["audioUrl"] as? String,
              let audioUrl = URL(string: "\(baseURL.replacingOccurrences(of: "/api", with: ""))\(audioUrlString)") else {
            return nil
        }
        
        // Fetch the actual audio file
        let (audioData, _) = try await URLSession.shared.data(from: audioUrl)
        return audioData
    }
    
    // MARK: - Set Character
    func setCharacter(_ character: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/character") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "character": character
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let _ = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Validate Connection Code
    func validateCode(_ code: String, deviceId: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/connect/validate") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "code": code,
            "deviceId": deviceId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            return json["success"] as? Bool ?? false
        }
        
        return false
    }
}

// MARK: - Response Types
struct MessageResponse {
    let success: Bool
    let messageId: String?
    let responseId: String?
    let source: String
}

struct ServerMessage {
    let id: String
    let text: String
    let from: String
    
    var isFromUser: Bool { from == "user" }
}

// MARK: - Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .serverError(let code): return "Server error: \(code)"
        case .noData: return "No data received"
        }
    }
}
