import Foundation

/// 可选的大模型教练服务：调用 OpenAI 兼容的 Chat Completion 接口，
/// 把训练概况转化为自然语言建议。Key 由用户在设置中提供，仅保存在本地。
actor AIService {

    struct Advice: Codable {
        let headline: String
        let suggestions: [String]
        let encouragement: String
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let response_format: [String: String]
    }

    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable {
                let content: String
            }
            let message: Msg
        }
        let choices: [Choice]
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 根据训练数据生成建议。
    /// - Parameters:
    ///   - endpoint: 自定义 OpenAI 兼容 API 的 BaseURL，例如 https://api.openai.com/v1
    ///   - apiKey:   Bearer Token
    ///   - model:    模型名，如 gpt-4o-mini
    ///   - summary:  训练概况
    func generateAdvice(endpoint: String, apiKey: String, model: String, summary: WorkoutSummary) async throws -> Advice {
        guard !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines) + "/chat/completions") else {
            throw AIServiceError.invalidEndpoint
        }

        let system = """
        你是一名耐心的健身教练。给用户简短、可执行的训练建议（中文）。
        输出 JSON 格式，包含 headline、suggestions（数组，每条一句话）、encouragement 三个字段。
        不要超过 200 字。
        """

        let user = """
        用户刚完成了一组训练，请基于以下数据给出 1~3 条改进建议与一句鼓励：
        - 动作：\(summary.exerciseName)
        - 时长：\(Int(summary.duration)) 秒
        - 次数：\(summary.reps)
        - 等长保持秒数：\(String(format: "%.1f", summary.holdSeconds))
        - 平均质量分：\(Int(summary.avgQuality))
        - 常见错误：\(summary.frequentIssues.isEmpty ? "无明显错误" : summary.frequentIssues.joined(separator: "；"))
        """

        let body = ChatRequest(
            model: model.isEmpty ? "gpt-4o-mini" : model,
            messages: [
                Message(role: "system", content: system),
                Message(role: "user", content: user)
            ],
            temperature: 0.7,
            response_format: ["type": "json_object"]
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIServiceError.requestFailed
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw AIServiceError.decodeFailed
        }
        return try JSONDecoder().decode(Advice.self, from: jsonData)
    }
}

/// 训练概况：交给 AI 服务的摘要数据。
struct WorkoutSummary {
    let exerciseName: String
    let duration: TimeInterval
    let reps: Int
    let holdSeconds: Double
    let avgQuality: Double
    let frequentIssues: [String]
}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint
    case requestFailed
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:  return "请先在设置中填写 API Key"
        case .invalidEndpoint: return "API 端点 URL 不合法"
        case .requestFailed:   return "请求 AI 服务失败"
        case .decodeFailed:    return "解析 AI 响应失败"
        }
    }
}