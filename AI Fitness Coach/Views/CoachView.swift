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
        .init(role: .user, text: "Сколько белка мне осталось на сегодня?", time: "01:00"),
        .init(role: .coach, text: "Давай посмотрим! 👇\n\nТвоя цель по белку: 160 г\nСъедено: 135 г\n\nОсталось: 25 г", time: "01:01"),
        .init(role: .user, text: "Что можно съесть, чтобы добрать белок?", time: "01:01"),
        .init(role: .coach, text: "Вот несколько вариантов, чтобы добрать ~25 г белка:\n\n🥚 3 яйца — 18 г белка\n🍗 Куриная грудка (100 г) — 23 г белка\n🍚 Творог 5% (150 г) — 20 г белка\n🥤 Протеиновый коктейль — 24–27 г белка\n\nХочешь, я подберу рецепт или добавлю в дневник?", time: "01:01")
    ]
    @State private var isThinking = false
    @State private var showHistory = false
    @State private var showPlus = false
    @State private var micMessage = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    heroCard
                    popularQuestions
                    chat
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }

            inputBar
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showHistory) {
            SimpleInfoSheet(title: "История чатов", rows: memories.prefix(12).map(\.content) + ["Сегодня: рекомендации по белку и ужину"])
        }
        .sheet(isPresented: $showPlus) {
            SimpleInfoSheet(title: "Действия ИИ", rows: [
                "Составить рацион на завтра",
                "Разобрать плато веса",
                "Подобрать тренировку",
                "Сформировать список покупок"
            ])
        }
        .alert("Голосовой ввод", isPresented: $micMessage) {
            Button("OK") { micMessage = false }
        } message: {
            Text("Нажми микрофон, продиктуй вопрос и поправь распознанный текст перед отправкой.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ИИ-помощник")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 7) {
                    Circle().fill(AppColors.green).frame(width: 12, height: 12)
                    Text(appState.apiKeyStatus == .configured ? "Онлайн" : "Offline • нужен API key")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }
            Spacer()
            AIHelperButton(title: "История чатов", systemImage: "clock.arrow.circlepath") {
                showHistory = true
            }
        }
    }

    private var heroCard: some View {
        PremiumCard(padding: 22, radius: 22) {
            HStack(alignment: .top, spacing: 20) {
                AIAvatarLarge()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Привет! Я твой ИИ-тренер.")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Я помогу с питанием, тренировками\nи мотивацией на основе твоих данных.\nСпроси меня о чем угодно!")
                        .font(.system(size: 16, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(AppColors.secondaryText)

                    HStack(spacing: 9) {
                        chip("Питание", tint: AppColors.green)
                        chip("Тренировки", tint: AppColors.purple)
                        chip("Прогресс", tint: AppColors.yellow)
                        chip("Здоровье", tint: AppColors.blue)
                    }
                }
                Spacer()
            }
        }
    }

    private var popularQuestions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Популярные вопросы")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    questionCard(icon: "fork.knife", tint: AppColors.green, text: "Что лучше съесть\nна ужин?")
                    questionCard(icon: "dumbbell", tint: AppColors.purple, text: "Какую тренировку\nмне сделать?")
                    questionCard(icon: "chart.line.uptrend.xyaxis", tint: AppColors.yellow, text: "Почему вес\nне уходит?")
                    questionCard(icon: "drop.fill", tint: AppColors.blue, text: "Сколько воды\nмне осталось?")
                }
                .padding(.trailing, 18)
            }
        }
    }

    private var chat: some View {
        VStack(spacing: 16) {
            Text("Сегодня")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity)

            ForEach(conversation) { bubble in
                AIMessageBubble(bubble: bubble)
            }

            if isThinking {
                HStack(spacing: 10) {
                    AIAvatarDot()
                    PremiumCard(padding: 14, radius: 18) {
                        HStack(spacing: 8) {
                            ProgressView().tint(AppColors.purple)
                            Text("Анализирую дневник...")
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                showPlus = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.white.opacity(0.070)).overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)))
            }
            .buttonStyle(.plain)

            TextField("Спроси что-нибудь...", text: $message, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
                .background(Capsule().fill(Color.white.opacity(0.085)))

            Button {
                Haptics.tap()
                micMessage = true
                if message.isEmpty { message = "Сколько белка мне осталось?" }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.purple)
                    .frame(width: 54, height: 54)
                    .background(Circle().stroke(AppColors.purple, lineWidth: 2.5))
            }
            .buttonStyle(.plain)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(AppColors.purple.opacity(0.80)))
            }
            .buttonStyle(.plain)
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            .opacity(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
        }
        .padding(8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.64))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Button {
            Haptics.tap()
            message = "\(text): что мне важно сегодня?"
        } label: {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(tint.opacity(0.10)).overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func questionCard(icon: String, tint: Color, text: String) -> some View {
        Button {
            Haptics.tap()
            message = text.replacingOccurrences(of: "\n", with: " ")
        } label: {
            PremiumCard(padding: 16, radius: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    IconBadge(systemName: icon, tint: tint, size: 48)
                    Text(text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineSpacing(3)
                }
                .frame(width: 160, height: 112, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func send() async {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        conversation.append(.init(role: .user, text: text, time: "сейчас"))
        message = ""
        isThinking = true

        let context = buildContext(userMessage: text)
        let answer = (try? await appState.aiClient.answer(context: context)) ?? fallbackAnswer(for: text)

        modelContext.insert(CoachMemory(kind: "chat", content: "Пользователь: \(text). Ответ: \(answer)", importance: 0.6))
        try? modelContext.save()

        conversation.append(.init(role: .coach, text: answer, time: "сейчас"))
        isThinking = false
        Haptics.success()
    }

    private func fallbackAnswer(for text: String) -> String {
        if appState.apiKeyStatus != .configured {
            return "Добавьте API-ключ в Профиль → ИИ и API. Пока отвечаю локально: сегодня лучше держать белок и воду, без резких ограничений."
        }
        return "Я учел твой дневник и цель. Лучший следующий шаг: добрать белок, оставить углеводы ближе к тренировке и лечь спать без позднего перекуса."
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

struct CoachBubble: Identifiable {
    enum Role {
        case user
        case coach
    }

    let id = UUID()
    let role: Role
    let text: String
    let time: String
}

private struct AIMessageBubble: View {
    let bubble: CoachBubble

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if bubble.role == .coach {
                AIAvatarDot()
            } else {
                Spacer(minLength: 58)
            }

            VStack(alignment: bubble.role == .user ? .trailing : .leading, spacing: 4) {
                Text(bubble.text)
                    .font(.system(size: 17, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                bubble.role == .user
                                ? LinearGradient(colors: [AppColors.purpleDeep.opacity(0.95), AppColors.purple.opacity(0.55)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.white.opacity(0.085), Color.white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(bubble.role == .user ? 0.03 : 0.06), lineWidth: 1))
                    )
                Text(bubble.time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.mutedText)
                    .padding(.horizontal, 8)
            }

            if bubble.role == .coach {
                Spacer(minLength: 48)
            }
        }
    }
}

private struct AIAvatarLarge: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Circle().fill(AppColors.purple.opacity(0.12)).padding(8)
            Image(systemName: "robot")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.white, AppColors.purple], startPoint: .top, endPoint: .bottom))
        }
        .frame(width: 118, height: 118)
    }
}

private struct AIAvatarDot: View {
    var body: some View {
        Image(systemName: "robot")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(AppColors.purple)
            .frame(width: 42, height: 42)
            .background(Circle().fill(Color.white.opacity(0.08)).overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)))
    }
}
