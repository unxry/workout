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
    case missingFolderID
    case badStatus(Int, String)
    case emptyResponse
    case invalidStructuredResponse
    case noInternet
    case requestTimedOut
    case imageUnsupported
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Добавьте API key Yandex Cloud в Профиль -> Алиса AI."
        case .missingFolderID:
            return "Добавьте Folder ID Yandex Cloud в Профиль -> Алиса AI."
        case .badStatus(let code, let body):
            if code == 401 || code == 403 { return "Yandex Cloud отклонил ключ или Folder ID. Проверьте настройки Алисы AI." }
            if code == 429 { return "Yandex AI вернул rate limit. Попробуйте позже." }
            return "Ошибка Yandex AI \(code): \(body.prefix(160))"
        case .emptyResponse:
            return "Yandex AI вернул пустой ответ."
        case .invalidStructuredResponse:
            return "Yandex AI вернул ответ в неверном формате."
        case .noInternet:
            return "Нет подключения к интернету."
        case .requestTimedOut:
            return "Запрос к Алисе занял слишком много времени. Попробуйте еще раз."
        case .imageUnsupported:
            return "Фото-анализ через Yandex AI пока не настроен для выбранной модели. Я не буду придумывать еду по фото."
        case .transport(let message):
            return message
        }
    }

    static func from(_ error: Error) -> AIClientError {
        if let aiError = error as? AIClientError { return aiError }
        guard let urlError = error as? URLError else {
            return .transport(error.localizedDescription)
        }

        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff:
            return .noInternet
        case .timedOut:
            return .requestTimedOut
        default:
            return .transport(urlError.localizedDescription)
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

struct AIImageAttachmentPayload: Equatable {
    let dataURL: String

    init(imageData: Data, mimeType: String) {
        dataURL = "data:\(mimeType);base64,\(imageData.base64EncodedString())"
    }
}

enum FoodAnalysisValidator {
    static func normalized(_ analysis: FoodPhotoAnalysis) -> FoodPhotoAnalysis {
        var normalized = analysis
        normalized.confidence = min(max(normalized.confidence, 0), 1)

        if normalized.status != .food {
            normalized.items = []
            normalized.total = nil
            if normalized.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalized.message = normalized.status == .notFood
                ? "На фотографии не обнаружена еда."
                : "Не удалось уверенно определить блюдо. Попробуйте другое фото."
            }
            return normalized
        }

        if normalized.confidence < 0.45 || normalized.items.isEmpty || normalized.total == nil {
            normalized.status = .uncertain
            normalized.items = []
            normalized.total = nil
            normalized.message = "Не удалось уверенно определить блюдо. Попробуйте другое фото."
        }

        return normalized
    }
}

protocol AIProvider {
    func answer(context: CoachContext) async throws -> String
    func parseFoodText(_ text: String, context: String) async throws -> FoodPhotoAnalysis
    func analyzeFoodImage(imageData: Data, mimeType: String, context: String) async throws -> FoodPhotoAnalysis
    func answerWithImage(imageData: Data, mimeType: String, context: CoachContext) async throws -> String
    func testConnection() async throws
}

struct AliceConfiguration: Equatable {
    var apiKey: String
    var folderID: String
    var model: String

    static var stored: AliceConfiguration {
        AliceConfiguration(
            apiKey: KeychainStore.shared.readYandexAPIKey(),
            folderID: KeychainStore.shared.readYandexFolderID(),
            model: "yandexgpt-lite"
        )
    }
}

final class YandexAIProvider: AIProvider {
    private let endpoint = URL(string: "https://llm.api.cloud.yandex.net/foundationModels/v1/completion")!

    func answer(context: CoachContext) async throws -> String {
        let request = YandexCompletionRequest(
            modelUri: try modelURI(),
            completionOptions: .init(stream: false, temperature: 0.45, maxTokens: "900"),
            messages: [
                .init(role: "system", text: systemPrompt),
                .init(role: "user", text: prompt(from: context))
            ]
        )
        let decoded: YandexCompletionResponse = try await post(request)
        guard let answer = decoded.result.alternatives.first?.message.text.trimmingCharacters(in: .whitespacesAndNewlines), !answer.isEmpty else {
            throw AIClientError.emptyResponse
        }
        return answer
    }

    func parseFoodText(_ text: String, context: String) async throws -> FoodPhotoAnalysis {
        let request = YandexCompletionRequest(
            modelUri: try modelURI(),
            completionOptions: .init(stream: false, temperature: 0.1, maxTokens: "700"),
            messages: [
                .init(role: "system", text: foodJSONPrompt),
                .init(role: "user", text: "Контекст: \(context)\nТекст пользователя: \(text)")
            ]
        )
        let decoded: YandexCompletionResponse = try await post(request)
        return try decodeFoodAnalysis(from: decoded)
    }

    func analyzeFoodImage(imageData: Data, mimeType: String = "image/jpeg", context: String) async throws -> FoodPhotoAnalysis {
        throw AIClientError.imageUnsupported
    }

    func answerWithImage(imageData: Data, mimeType: String = "image/jpeg", context: CoachContext) async throws -> String {
        throw AIClientError.imageUnsupported
    }

    func testConnection() async throws {
        let request = YandexCompletionRequest(
            modelUri: try modelURI(),
            completionOptions: .init(stream: false, temperature: 0, maxTokens: "16"),
            messages: [
                .init(role: "system", text: "Ответь ровно: OK"),
                .init(role: "user", text: "ping")
            ]
        )
        let decoded: YandexCompletionResponse = try await post(request)
        guard decoded.result.alternatives.first?.message.text.isEmpty == false else {
            throw AIClientError.emptyResponse
        }
    }

    private var systemPrompt: String {
        """
        Ты Алиса AI, персональный помощник по питанию, весу, прогрессу, воде, активности и привычкам.
        Отвечай по-русски, коротко, спокойно и конкретно. Используй только переданный fitness context.
        Не придумывай базовые цели: BMR, TDEE, калории и БЖУ уже рассчитаны приложением.
        Не рекомендуй голодание, опасно низкие калории, обезвоживание или наказание тренировкой за еду.
        Если есть медицинские риски, мягко предложи обратиться к врачу.
        """
    }

    private var foodJSONPrompt: String {
        """
        Ты извлекаешь прием пищи из текста пользователя. Верни только JSON без markdown.
        Формат:
        {"status":"FOOD|NOT_FOOD|UNCERTAIN","confidence":0.0,"message":"короткое сообщение по-русски","items":[{"name":"...","estimated_grams":100,"calories":120,"protein":10,"fat":3,"carbs":12}],"total":{"calories":120,"protein":10,"fat":3,"carbs":12}}
        Если в тексте нет еды, status=NOT_FOOD, items=[], total=null.
        Если порция непонятна, status=UNCERTAIN, объясни что уточнить.
        Калории и БЖУ приблизительные, без random fallback.
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

    private func modelURI() throws -> String {
        let config = AliceConfiguration.stored
        guard !config.folderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingFolderID
        }
        return "gpt://\(config.folderID)/\(config.model)"
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(_ body: RequestBody) async throws -> ResponseBody {
        let apiKey = AliceConfiguration.stored.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIClientError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIClientError.from(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.emptyResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIClientError.badStatus(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw AIClientError.invalidStructuredResponse
        }
    }

    private func decodeFoodAnalysis(from decoded: YandexCompletionResponse) throws -> FoodPhotoAnalysis {
        guard let content = decoded.result.alternatives.first?.message.text.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw AIClientError.emptyResponse
        }
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8), let analysis = try? JSONDecoder().decode(FoodPhotoAnalysis.self, from: data) else {
            throw AIClientError.invalidStructuredResponse
        }
        return FoodAnalysisValidator.normalized(analysis)
    }
}

private struct YandexCompletionRequest: Encodable {
    let modelUri: String
    let completionOptions: CompletionOptions
    let messages: [YandexMessage]
}

private struct CompletionOptions: Encodable {
    let stream: Bool
    let temperature: Double
    let maxTokens: String
}

private struct YandexMessage: Codable {
    let role: String
    let text: String
}

private struct YandexCompletionResponse: Decodable {
    let result: Result

    struct Result: Decodable {
        let alternatives: [Alternative]
    }

    struct Alternative: Decodable {
        let message: YandexMessage
    }
}
