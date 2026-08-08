import SwiftData
import SwiftUI

struct CoachView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \CoachMemory.createdAt, order: .reverse) private var memories: [CoachMemory]

    @State private var message = ""
    @State private var conversation: [CoachBubble] = [
        .init(role: .coach, text: "Я рядом. Можешь спросить про питание, вес, тренировку или почему прогресс замедлился.")
    ]
    @State private var isThinking = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI Coach")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(appState.apiKeyStatus == .configured ? "OpenAI подключен" : "Работает fallback-логика")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(conversation) { bubble in
                        HStack {
                            if bubble.role == .user { Spacer(minLength: 42) }
                            Text(bubble.text)
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(bubble.role == .user ? Color.purpleAccent.opacity(0.88) : .white.opacity(0.08))
                                )
                            if bubble.role == .coach { Spacer(minLength: 42) }
                        }
                    }

                    if isThinking {
                        HStack {
                            ProgressView()
                                .tint(Color.purpleAccent)
                            Text("Анализирую память и дневник...")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.62))
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            HStack(spacing: 10) {
                TextField("Спроси AI Coach", text: $message, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.08)))

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.purpleAccent))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
    }

    private func send() async {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        conversation.append(.init(role: .user, text: text))
        message = ""
        isThinking = true

        let context = buildContext(userMessage: text)
        let answer = (try? await appState.aiClient.answer(context: context)) ?? "Сейчас не получилось связаться с AI API. Я сохранил вопрос и вернусь к нему позже."

        modelContext.insert(CoachMemory(kind: "chat", content: "Пользователь: \(text). Ответ: \(answer)", importance: 0.6))
        try? modelContext.save()

        conversation.append(.init(role: .coach, text: answer))
        isThinking = false
    }

    private func buildContext(userMessage: String) -> CoachContext {
        let profile = profiles.first
        let targets = profile.map { NutritionCalculator.targets(for: $0) }
        let todayMeals = meals.filter { Calendar.current.isDateInToday($0.date) }
        let calories = todayMeals.reduce(0) { $0 + $1.calories }
        let protein = todayMeals.reduce(0) { $0 + $1.protein }

        return CoachContext(
            profileSummary: profile.map { "\($0.name), цель \($0.goal.rawValue), вес \($0.currentWeightKg), цель \($0.targetWeightKg)" } ?? "Профиль еще не заполнен",
            todayNutrition: targets.map { "\(Int(calories))/\(Int($0.calories)) ккал, белок \(Int(protein))/\(Int($0.protein)) г" } ?? "Нет цели",
            recentTrend: "Локальные записи веса используются для оценки плато и скорости прогресса.",
            memories: memories.prefix(8).map(\.content),
            userMessage: userMessage
        )
    }
}

private struct CoachBubble: Identifiable {
    enum Role {
        case user
        case coach
    }

    let id = UUID()
    let role: Role
    let text: String
}
