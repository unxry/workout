import Foundation

struct CoachContext: Encodable {
    let profileSummary: String
    let todayNutrition: String
    let recentTrend: String
    let memories: [String]
    let userMessage: String
}

enum AIClientError: LocalizedError, Equatable {
    case missingAPIKey
    case badStatus(Int, String)
    case emptyResponse
    case invalidStructuredResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Добавьте OpenAI API key в Профиль -> ИИ и API."
        case .badStatus(let code, let body):
            if code == 401 { return "OpenAI API key отклонен. Проверьте ключ в настройках." }
            if code == 429 { return "OpenAI вернул rate limit. Попробуйте позже." }
            return "OpenAI error \(code): \(body.prefix(160))"
        case .emptyResponse:
            return "OpenAI вернул пустой ответ."
        case .invalidStructuredResponse:
            return "OpenAI вернул ответ в неверном формате."
        }
    }
}

enum FoodImageStatus: String, Codable, Equatable {
    case food = "FOOD"
    case notFood = "NOT_FOOD"
    case uncertain = "UNCERTAIN"
}

struct NutritionEstimateTotal: Codable, Equatable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
}

struct FoodEstimateItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var estimatedGrams: Double
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double

    enum CodingKeys: String, CodingKey {
        case name
        case estimatedGrams = "estimated_grams"
        case calories
        case protein
        case fat
        case carbs
    }
}

struct FoodPhotoAnalysis: Codable, Equatable {
    var status: FoodImageStatus
    var confidence: Double
    var message: String
    var items: [FoodEstimateItem]
    var total: NutritionEstimateTotal?

    var isFood: Bool { status == .food && total != nil && !items.isEmpty }
}

final class OpenAIClient {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func answer(context: CoachContext) async throws -> String {
        let apiKey = try apiKey()
        let body = TextChatCompletionRequest(
            model: "gpt-4.1-mini",
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: prompt(from: context))
            ],
            temperature: 0.55,
            responseFormat: nil
        )
        let decoded: ChatCompletionResponse = try await post(body, apiKey: apiKey)
        guard let answer = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !answer.isEmpty else {
            throw AIClientError.emptyResponse
        }
        return answer
    }

    func parseFoodText(_ text: String, context: String) async throws -> FoodPhotoAnalysis {
        let apiKey = try apiKey()
        let body = TextChatCompletionRequest(
            model: "gpt-4.1-mini",
            messages: [
                .init(role: "system", content: foodJSONPrompt),
                .init(role: "user", content: "Контекст: \(context)\nТекст пользователя: \(text)")
            ],
            temperature: 0.15,
            responseFormat: .jsonObject
        )
        let decoded: ChatCompletionResponse = try await post(body, apiKey: apiKey)
        return try decodeFoodAnalysis(from: decoded)
    }

    func analyzeFoodImage(imageData: Data, mimeType: String = "image/jpeg", context: String) async throws -> FoodPhotoAnalysis {
        let apiKey = try apiKey()
        let imageURL = "data:\(mimeType);base64,\(imageData.base64EncodedString())"
        let body = VisionChatCompletionRequest(
            model: "gpt-4.1-mini",
            messages: [
                .init(role: "system", content: [.text(foodVisionPrompt)]),
                .init(role: "user", content: [
                    .text("Контекст пользователя: \(context). Сначала реши, есть ли на фото еда. Не придумывай блюдо, если еды нет."),
                    .imageURL(.init(url: imageURL))
                ])
            ],
            temperature: 0.10,
            responseFormat: .jsonObject
        )
        let decoded: ChatCompletionResponse = try await post(body, apiKey: apiKey)
        return try decodeFoodAnalysis(from: decoded)
    }

    func testConnection() async throws {
        let apiKey = try apiKey()
        let body = TextChatCompletionRequest(
            model: "gpt-4.1-mini",
            messages: [
                .init(role: "system", content: "Return exactly OK."),
                .init(role: "user", content: "ping")
            ],
            temperature: 0,
            responseFormat: nil
        )
        let decoded: ChatCompletionResponse = try await post(body, apiKey: apiKey)
        guard decoded.choices.first?.message.content.isEmpty == false else {
            throw AIClientError.emptyResponse
        }
    }

    private var systemPrompt: String {
        """
        Ты персональный AI Fitness Coach. Отвечай по-русски, коротко, спокойно и конкретно.
        Используй данные пользователя, долгосрочную память, питание, вес, сон, шаги и цель.
        Не назначай медицинское лечение. При рисках мягко советуй обратиться к врачу.
        Давай действия на сегодня: питание, активность, сон, тренировка или восстановление.
        """
    }

    private var foodVisionPrompt: String {
        """
        Ты анализируешь изображение для фитнес-дневника. Верни только JSON.
        Сначала классифицируй фото:
        FOOD - еда или напиток явно видны.
        NOT_FOOD - еды/напитка нет.
        UNCERTAIN - изображение нечеткое или еды может не быть.
        Если NOT_FOOD или UNCERTAIN, items должен быть пустым, total должен быть null.
        Если FOOD, оцени продукты, граммы и БЖУ приблизительно.
        Формат:
        {"status":"FOOD|NOT_FOOD|UNCERTAIN","confidence":0.0,"message":"короткое сообщение по-русски","items":[{"name":"...","estimated_grams":100,"calories":120,"protein":10,"fat":3,"carbs":12}],"total":{"calories":120,"protein":10,"fat":3,"carbs":12}}
        """
    }

    private var foodJSONPrompt: String {
        """
        Ты извлекаешь прием пищи из текста пользователя. Верни только JSON в формате:
        {"status":"FOOD|NOT_FOOD|UNCERTAIN","confidence":0.0,"message":"короткое сообщение по-русски","items":[{"name":"...","estimated_grams":100,"calories":120,"protein":10,"fat":3,"carbs":12}],"total":{"calories":120,"protein":10,"fat":3,"carbs":12}}
        Если в тексте нет еды, status=NOT_FOOD, items=[], total=null.
        Если порция непонятна, status=UNCERTAIN, объясни что уточнить.
        """
    }

    private func prompt(from context: CoachContext) -> String {
        """
        Профиль: \(context.profileSummary)
        Сегодня: \(context.todayNutrition)
        Тренд: \(context.recentTrend)
        Память: \(context.memories.joined(separator: " | "))
        Сообщение пользователя: \(context.userMessage)
        """
    }

    private func apiKey() throws -> String {
        let key = KeychainStore.shared.readOpenAIKey()
        guard !key.isEmpty else { throw AIClientError.missingAPIKey }
        return key
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(_ body: RequestBody, apiKey: String) async throws -> ResponseBody {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.emptyResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIClientError.badStatus(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }

    private func decodeFoodAnalysis(from decoded: ChatCompletionResponse) throws -> FoodPhotoAnalysis {
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw AIClientError.emptyResponse
        }
        guard let data = content.data(using: .utf8), let analysis = try? JSONDecoder().decode(FoodPhotoAnalysis.self, from: data) else {
            throw AIClientError.invalidStructuredResponse
        }
        return analysis
    }
}

private struct TextChatCompletionRequest: Encodable {
    let model: String
    let messages: [TextChatMessage]
    let temperature: Double
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }
}

private struct TextChatMessage: Codable {
    let role: String
    let content: String
}

private struct VisionChatCompletionRequest: Encodable {
    let model: String
    let messages: [VisionChatMessage]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }
}

private struct VisionChatMessage: Encodable {
    let role: String
    let content: [VisionContent]
}

private enum VisionContent: Encodable {
    case text(String)
    case imageURL(ImageURL)

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

private struct ImageURL: Encodable {
    let url: String
}

private struct ResponseFormat: Encodable {
    static let jsonObject = ResponseFormat(type: "json_object")
    let type: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String
    }
}
