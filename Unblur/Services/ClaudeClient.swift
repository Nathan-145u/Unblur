//
//  ClaudeClient.swift
//  Unblur — minimal Anthropic Messages API client (no SDK)
//

import Foundation

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case decode

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing Claude API key. Set it in Settings."
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .decode: return "Failed to decode response"
        }
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

final class ClaudeClient {
    static let shared = ClaudeClient()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-haiku-4-5-20251001"

    func complete(system: String?, messages: [ClaudeMessage], maxTokens: Int = 1024) async throws -> String {
        guard let apiKey = KeychainHelper.get(SecretKey.claudeAPIKey), !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        if let system { body["system"] = system }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.decode }
        if http.statusCode >= 400 {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeError.http(http.statusCode, bodyStr)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArr = json["content"] as? [[String: Any]]
        else { throw ClaudeError.decode }
        let text = contentArr.compactMap { $0["text"] as? String }.joined()
        return text
    }
}
