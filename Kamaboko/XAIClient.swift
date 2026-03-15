import Foundation

struct XAIChatClient {
    struct APIError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private enum EndpointKind {
        case chatCompletions
        case responses
    }

    private struct Endpoint {
        let url: URL
        let kind: EndpointKind
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            enum Content: Encodable {
                case text(String)
                case imageURL(ImageURL)

                struct ImageURL: Encodable {
                    let url: String
                    let detail: String?
                }

                enum CodingKeys: String, CodingKey {
                    case type
                    case text
                    case imageURL = "image_url"
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    switch self {
                    case .text(let text):
                        try container.encode("text", forKey: .type)
                        try container.encode(text, forKey: .text)
                    case .imageURL(let imageURL):
                        try container.encode("image_url", forKey: .type)
                        try container.encode(imageURL, forKey: .imageURL)
                    }
                }
            }

            let role: String
            let content: [Content]
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message
        }

        let choices: [Choice]
    }

    private struct ResponsesRequest: Encodable {
        struct Input: Encodable {
            struct Content: Encodable {
                enum Payload: Encodable {
                    case text(String)
                    case imageURL(ImageURL)

                    struct ImageURL: Encodable {
                        let url: String
                    }

                    enum CodingKeys: String, CodingKey {
                        case type
                        case text
                        case imageURL = "image_url"
                    }

                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        switch self {
                        case .text(let text):
                            try container.encode("input_text", forKey: .type)
                            try container.encode(text, forKey: .text)
                        case .imageURL(let imageURL):
                            try container.encode("input_image", forKey: .type)
                            try container.encode(imageURL, forKey: .imageURL)
                        }
                    }
                }

                let payload: Payload

                func encode(to encoder: Encoder) throws {
                    try payload.encode(to: encoder)
                }
            }

            let role: String
            let content: [Content]
        }

        let model: String
        let input: [Input]
        let temperature: Double
        let maxOutputTokens: Int

        enum CodingKeys: String, CodingKey {
            case model
            case input
            case temperature
            case maxOutputTokens = "max_output_tokens"
        }
    }

    private struct ResponsesResponse: Decodable {
        struct Output: Decodable {
            struct Content: Decodable {
                let type: String?
                let text: String?
            }

            let content: [Content]?
        }

        let outputText: String?
        let output: [Output]?

        enum CodingKeys: String, CodingKey {
            case outputText = "output_text"
            case output
        }
    }

    struct LabCheckAISuggestion: Decodable {
        let intervalWeeks: Int
        let reason: String

        enum CodingKeys: String, CodingKey {
            case intervalWeeks = "interval_weeks"
            case reason
        }
    }

    static func generateLabCheckSuggestion(
        hrtStartDate: Date,
        latestReport: LabReport?,
        languageCode: String,
        apiKey: String,
        baseURL: String,
        model: String
    ) async throws -> LabCheckAISuggestion {
        let systemPrompt = labCheckSystemPrompt(for: languageCode)
        let userPrompt = labCheckUserPrompt(hrtStartDate: hrtStartDate, latestReport: latestReport, languageCode: languageCode)

        let requestBody = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: [.text(systemPrompt)]),
                .init(role: "user", content: [.text(userPrompt)])
            ],
            temperature: 0.2,
            maxTokens: 200
        )

        let response = try await sendChat(requestBody, apiKey: apiKey, baseURL: baseURL)
        let data = Data(response.utf8)
        return try JSONDecoder().decode(LabCheckAISuggestion.self, from: data)
    }

    static func generateRLESupport(
        entry: RLEEntry,
        languageCode: String,
        apiKey: String,
        baseURL: String,
        model: String
    ) async throws -> String {
        let systemPrompt = systemPromptText(for: languageCode)
        let userPrompt = userPromptText(for: entry, languageCode: languageCode)

        let requestBody = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: [.text(systemPrompt)]),
                .init(role: "user", content: [.text(userPrompt)])
            ],
            temperature: 0.7,
            maxTokens: 240
        )

        return try await sendChat(requestBody, apiKey: apiKey, baseURL: baseURL)
    }

    static func generateRLESupportWithImages(
        entry: RLEEntry,
        languageCode: String,
        apiKey: String,
        baseURL: String,
        model: String,
        currentImageDataURL: String,
        previousImageDataURL: String?,
        historyImageDataURLs: [String]
    ) async throws -> String {
        let systemPrompt = systemPromptText(for: languageCode)
        let userText = userPromptText(for: entry, languageCode: languageCode)
        let instruction = comparisonInstruction(for: languageCode, hasPrevious: previousImageDataURL != nil, historyCount: historyImageDataURLs.count)

        let endpoint = resolveEndpoint(baseURL)
        switch endpoint.kind {
        case .chatCompletions:
            var userContents: [ChatRequest.Message.Content] = [
                .text(userText),
                .text(instruction),
                .imageURL(.init(url: currentImageDataURL, detail: "low"))
            ]

            if let previousImageDataURL {
                userContents.append(.imageURL(.init(url: previousImageDataURL, detail: "low")))
            }

            if !historyImageDataURLs.isEmpty {
                for url in historyImageDataURLs {
                    userContents.append(.imageURL(.init(url: url, detail: "low")))
                }
            }

            let requestBody = ChatRequest(
                model: model,
                messages: [
                    .init(role: "system", content: [.text(systemPrompt)]),
                    .init(role: "user", content: userContents)
                ],
                temperature: 0.6,
                maxTokens: 320
            )

            return try await sendChat(requestBody, apiKey: apiKey, baseURL: baseURL)
        case .responses:
            var contents: [ResponsesRequest.Input.Content] = [
                .init(payload: .text(userText)),
                .init(payload: .text(instruction)),
                .init(payload: .imageURL(.init(url: currentImageDataURL)))
            ]

            if let previousImageDataURL {
                contents.append(.init(payload: .imageURL(.init(url: previousImageDataURL))))
            }

            if !historyImageDataURLs.isEmpty {
                for url in historyImageDataURLs {
                    contents.append(.init(payload: .imageURL(.init(url: url))))
                }
            }

            let requestBody = ResponsesRequest(
                model: model,
                input: [
                    .init(role: "user", content: contents)
                ],
                temperature: 0.6,
                maxOutputTokens: 320
            )

            return try await sendResponses(requestBody, apiKey: apiKey, baseURL: baseURL)
        }
    }

    private static func systemPromptText(for languageCode: String) -> String {
        switch languageCode {
        case "en":
            return "The user is a transgender woman. Analyze changes related to HRT and RLE using the provided photos. Provide objective observations, then add a brief positive encouragement.  Keep it concise: 1 short paragraph."
        case "zh-Hant":
            return "用戶是一名跨性別女性，希望你透過照片分析其HRT與RLE的變化，在客觀分析變化的基礎上給予正向鼓勵。保持精簡：1 段短文。"
        default:
            return "用户是一名跨性别女性，希望你通过照片分析其HRT与RLE的变化，在客观分析变化的基础上给予正向鼓励。保持精简：1 段短文。"
        }
    }

    private static func labCheckSystemPrompt(for languageCode: String) -> String {
        switch languageCode {
        case "en":
            return "You are a clinical assistant. Based on the provided HRT start date and latest lab report summary, suggest a lab recheck interval in weeks. Output ONLY strict JSON: {\"interval_weeks\": number, \"reason\": \"...\"}. No extra text."
        case "zh-Hant":
            return "你是一名臨床助理。根據提供的 HRT 開始日期與最近一次化驗摘要，建議復查間隔（週）。僅輸出嚴格 JSON：{\"interval_weeks\": 數字, \"reason\": \"...\"}，不要輸出其他文字。"
        default:
            return "你是一名临床助理。根据提供的 HRT 开始日期与最近一次化验摘要，建议复查间隔（周）。仅输出严格 JSON：{\"interval_weeks\": 数字, \"reason\": \"...\"}，不要输出其他文字。"
        }
    }

    private static func labCheckUserPrompt(hrtStartDate: Date, latestReport: LabReport?, languageCode: String) -> String {
        let startText = hrtStartDate.formatted(date: .abbreviated, time: .omitted)
        let reportText: String
        if let latestReport {
            let dateText = latestReport.date.formatted(date: .abbreviated, time: .omitted)
            reportText = """
Latest report date: \(dateText)
E2: \(latestReport.estradiolValue) \(latestReport.estradiolUnit.rawValue)
T: \(latestReport.testosteroneValue) \(latestReport.testosteroneUnit.rawValue)
Interpretation: \(latestReport.interpretation.rawValue)
Suggestion: \(latestReport.suggestion.rawValue)
"""
        } else {
            reportText = "Latest report: none"
        }

        return """
HRT start date: \(startText)
\(reportText)
"""
    }

    private static func userPromptText(for entry: RLEEntry, languageCode: String) -> String {
        let dateText = entry.date.formatted(date: .abbreviated, time: .omitted)

        let prompt = """
RLE photo log
Date: \(dateText)
"""
        return prompt
    }

    private static func comparisonInstruction(for languageCode: String, hasPrevious: Bool, historyCount: Int) -> String {
        let historyLine = historyCount > 0 ? "History images provided: \(historyCount)." : "No additional history images provided."
        switch languageCode {
        case "en":
            return "Compare the current photo with the most recent previous photo, and summarize overall changes across all past photos provided. Output 1 short paragraph that includes: (1) observable change trend, (2) objective summary, (3) brief positive encouragement. \(historyLine)"
        case "zh-Hant":
            return "請與最近一張舊照片對比，並綜合所有提供的過往照片描述變化趨勢。請輸出 1 段短文，包含：（1）可觀察到的變化趨勢，（2）客觀總結，（3）簡短正向鼓勵。\(historyLine)"
        default:
            return "请与最近一张旧照片对比，并综合所有提供的过往照片描述变化趋势。请输出 1 段短文：（1）可观察到的变化趋势，（2）客观总结。\(historyLine)"
        }
    }

    private static func resolveEndpoint(_ baseURL: String) -> Endpoint {
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedBase.hasSuffix("/") ? String(trimmedBase.dropLast()) : trimmedBase

        if base.contains("/v1/responses") {
            return Endpoint(url: URL(string: base)!, kind: .responses)
        }
        if base.contains("/v1/chat/completions") {
            return Endpoint(url: URL(string: base)!, kind: .chatCompletions)
        }

        let chatURL = URL(string: "\(base)/v1/chat/completions")!
        return Endpoint(url: chatURL, kind: .chatCompletions)
    }

    private static func sendChat(_ requestBody: ChatRequest, apiKey: String, baseURL: String) async throws -> String {
        let endpoint = resolveEndpoint(baseURL)
        guard endpoint.kind == .chatCompletions else {
            throw APIError(message: "Endpoint is not chat/completions")
        }
        return try await send(requestBody: requestBody, apiKey: apiKey, url: endpoint.url) { data in
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    private static func sendResponses(_ requestBody: ResponsesRequest, apiKey: String, baseURL: String) async throws -> String {
        let endpoint = resolveEndpoint(baseURL)
        guard endpoint.kind == .responses else {
            throw APIError(message: "Endpoint is not responses")
        }
        return try await send(requestBody: requestBody, apiKey: apiKey, url: endpoint.url) { data in
            let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
            if let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines), !outputText.isEmpty {
                return outputText
            }
            if let output = decoded.output,
               let first = output.first,
               let content = first.content {
                let joined = content.compactMap { $0.text }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                return joined
            }
            return ""
        }
    }

    private static func send<T: Encodable>(
        requestBody: T,
        apiKey: String,
        url: URL,
        decode: (Data) throws -> String
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw APIError(message: "API failed (\(httpResponse.statusCode)): \(raw)")
        }

        let content = try decode(data)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError(message: "Empty response")
        }
        return content
    }
}

