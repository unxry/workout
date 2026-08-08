import Foundation

struct CoachContext: Encodable {
    let profileSummary: String
    let todayNutrition: String
    let recentTrend: String
    let memories: [String]
    let userMessage: String
}

final class OpenAIClient {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func answer(context: CoachContext) async throws -> String {
        let apiKey = KeychainStore.shared.readOpenAIKey()
        guard !apiKey.isEmpty else {
            return fallbackAnswer(for: context)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatCompletionRequest(
            model: "gpt-4.1-mini",
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: prompt(from: context))
            ],
            temperature: 0.55
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            return fallbackAnswer(for: context)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? fallbackAnswer(for: context)
    }

    private var systemPrompt: String {
        """
        Ты персональный AI Fitness Coach. Отвечай по-русски, коротко, спокойно и конкретно.
        Используй данные пользователя, долгосрочную память, питание, вес, сон, шаги и цель.
        Не назначай медицинское лечение. При рисках мягко советуй обратиться к врачу.
        Давай действия на сегодня: питание, активность, сон, тренировка или восстановление.
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

    private func fallbackAnswer(for context: CoachContext) -> String {
        if context.userMessage.lowercased().contains("пиц") {
            return "Можно. Просто оставь ужин легче: больше белка, меньше быстрых углеводов, и добавь 20-30 минут прогулки."
        }

        return "Я уже учитываю твой профиль и записи. Сегодня держим фокус на белке, воде и шагах; если вес стоит несколько дней, меняем стратегию мягко, без голодовок."
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
