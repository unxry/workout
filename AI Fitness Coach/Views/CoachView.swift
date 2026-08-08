import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CoachView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \CoachMemory.createdAt, order: .reverse) private var memories: [CoachMemory]
    @Query(sort: \DailyMetric.date) private var metrics: [DailyMetric]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var workouts: [WorkoutLog]

    @StateObject private var speech = SpeechRecognitionService()
    @State private var message = ""
    @State private var conversation: [CoachBubble] = [
        .init(role: .coach, text: "Привет. Я готов анализировать питание, тренировки, вес и фото. Напиши вопрос или приложи снимок еды.", time: "сейчас")
    ]
    @State private var isThinking = false
    @State private var showHistory = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var attachedImage: UIImage?
    @State private var attachedImageData: Data?
    @State private var showImageSourceDialog = false
    @State private var showCamera = false
    @State private var inputError: String?

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
        .onChange(of: pickerItem) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                setAttachedImage(image)
            }
        }
        .onChange(of: speech.transcript) { _, transcript in
            if speech.isRecording || !transcript.isEmpty {
                message = transcript
            }
        }
        .onChange(of: speech.errorMessage) { _, value in
            inputError = value
        }
        .confirmationDialog("Добавить изображение", isPresented: $showImageSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { showCamera = true }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Photo Library")
            }
            Button("Отмена", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { captured in
                setAttachedImage(captured)
                showCamera = false
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if let prompt = appState.consumePendingCoachPrompt() {
                message = prompt
                Task { await send() }
            }
        }
        .onChange(of: appState.pendingCoachPrompt) { _, _ in
            if let prompt = appState.consumePendingCoachPrompt() {
                message = prompt
                Task { await send() }
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                headerTitle
                    .layoutPriority(1)
                AIHelperButton(title: "История чатов", systemImage: "clock.arrow.circlepath") {
                    showHistory = true
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                headerTitle
                AIHelperButton(title: "История чатов", systemImage: "clock.arrow.circlepath") {
                    showHistory = true
                }
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ИИ-помощник")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 7) {
                Circle().fill(AppColors.green).frame(width: 12, height: 12)
                Text(appState.apiKeyStatus == .configured ? "Онлайн" : "Offline • нужен API key")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }

    private var heroCard: some View {
        PremiumCard(padding: 22, radius: 22) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    AIAvatarLarge()
                    heroText
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 14) {
                        AIAvatarLarge(size: 86)
                        Text("Привет! Я твой ИИ-тренер.")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    heroDescription
                    chipScroll
                }
            }
        }
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Привет! Я твой ИИ-тренер.")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            heroDescription
            chipScroll
        }
    }

    private var heroDescription: some View {
        Text("Я помогу с питанием, тренировками и мотивацией на основе твоих данных. Спроси меня о чем угодно.")
            .font(.system(size: 16, weight: .regular))
            .lineSpacing(4)
            .foregroundStyle(AppColors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chipScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                chip("Питание", tint: AppColors.green)
                chip("Тренировки", tint: AppColors.purple)
                chip("Прогресс", tint: AppColors.yellow)
                chip("Здоровье", tint: AppColors.blue)
            }
            .padding(.trailing, 8)
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
        VStack(spacing: 8) {
            if let attachedImage {
                HStack(spacing: 10) {
                    Image(uiImage: attachedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("Фото будет отправлено ИИ вместе с вопросом.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        self.attachedImage = nil
                        self.attachedImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
                .padding(.horizontal, 10)
            }

            if let inputError {
                Text(inputError)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    showImageSourceDialog = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color.white.opacity(0.070)).overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)))
                }
                .buttonStyle(.plain)

                TextField(speech.isRecording ? "Слушаю..." : "Спроси что-нибудь...", text: $message, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
                .background(Capsule().fill(Color.white.opacity(0.085)))
                .layoutPriority(1)

                Button {
                    Haptics.tap()
                    if speech.isRecording {
                        speech.stop()
                    } else {
                        inputError = nil
                        Task { await speech.start() }
                    }
                } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(speech.isRecording ? AppColors.green : AppColors.purple)
                    .frame(width: 54, height: 54)
                    .background(Circle().stroke(speech.isRecording ? AppColors.green : AppColors.purple, lineWidth: 2.5))
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
                .disabled((message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImageData == nil) || isThinking)
                .opacity((message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImageData == nil) ? 0.55 : 1)
            }
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
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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
        guard !text.isEmpty || attachedImageData != nil else { return }

        let image = attachedImage
        let imageData = attachedImageData
        conversation.append(.init(role: .user, text: text.isEmpty ? "Проанализируй фото" : text, time: "сейчас", image: image))
        message = ""
        attachedImage = nil
        attachedImageData = nil
        isThinking = true

        let context = buildContext(userMessage: text)
        let answer: String
        do {
            if let imageData {
                answer = try await appState.aiClient.answerWithImage(imageData: imageData, context: context)
            } else {
                answer = try await appState.aiClient.answer(context: context)
            }
        } catch {
            answer = AIClientError.from(error).localizedDescription
        }

        modelContext.insert(CoachMemory(kind: "chat", content: "Пользователь: \(text). Ответ: \(answer)", importance: 0.6))
        try? modelContext.save()

        conversation.append(.init(role: .coach, text: answer, time: "сейчас"))
        isThinking = false
        Haptics.success()
    }

    private func setAttachedImage(_ image: UIImage) {
        do {
            let payload = try ImagePreparationService.prepareJPEG(from: image)
            attachedImageData = payload.data
            attachedImage = image
            inputError = nil
        } catch {
            inputError = error.localizedDescription
        }
    }

    private func formatFoodAnalysis(_ analysis: FoodPhotoAnalysis) -> String {
        switch analysis.status {
        case .notFood:
            return analysis.message.isEmpty ? "На фотографии не удалось обнаружить еду." : analysis.message
        case .uncertain:
            return analysis.message.isEmpty ? "Не уверен, что на фото еда. Попробуйте другое фото." : analysis.message
        case .food:
            guard let total = analysis.total else {
                return "Еда видна, но не удалось надежно оценить БЖУ. Попробуйте фото ближе к блюду."
            }
            let items = analysis.items.map { "• \($0.name), ~\(Int($0.estimatedGrams)) г" }.joined(separator: "\n")
            return """
            Примерная оценка:
            ~\(Int(total.calories)) ккал
            Б \(Int(total.protein)) г • Ж \(Int(total.fat)) г • У \(Int(total.carbs)) г

            \(items)

            Оценка по фото может отличаться из-за неизвестного веса порции, способа приготовления и ингредиентов.
            """
        }
    }

    private func buildContext(userMessage: String) -> CoachContext {
        let profile = profiles.first
        let targets = profile.map { NutritionCalculator.targets(for: $0) }
        let calendar = Calendar.current
        let todayMeals = meals.filter { calendar.isDateInToday($0.date) }
        let calories = todayMeals.reduce(0) { $0 + $1.calories }
        let protein = todayMeals.reduce(0) { $0 + $1.protein }
        let fat = todayMeals.reduce(0) { $0 + $1.fat }
        let carbs = todayMeals.reduce(0) { $0 + $1.carbs }
        let latestMetric = metrics.last
        let mealSummary = todayMeals.prefix(5).map { "\($0.title): \(Int($0.calories)) ккал" }.joined(separator: "; ")
        let workoutSummary = workouts.prefix(3).map { "\($0.title), \($0.durationMinutes) мин, \(Int($0.calories)) ккал" }.joined(separator: "; ")
        let trendSummary: String
        if let first = metrics.suffix(7).first, let last = metrics.suffix(7).last {
            trendSummary = "вес \(String(format: "%.1f", first.weightKg)) -> \(String(format: "%.1f", last.weightKg)) кг за последние записи"
        } else {
            trendSummary = "недостаточно записей веса для тренда"
        }

        return CoachContext(
            profileSummary: profile.map { "\($0.name), цель \($0.goal.rawValue), вес \($0.currentWeightKg), целевой вес \($0.targetWeightKg), рост \($0.heightCm), тренировок/нед \($0.trainingDaysPerWeek)" } ?? "Профиль еще не заполнен",
            todayNutrition: targets.map { "цель \(Int($0.calories)) ккал; съедено \(Int(calories)) ккал; Б \(Int(protein))/\(Int($0.protein)) г; Ж \(Int(fat))/\(Int($0.fat)) г; У \(Int(carbs))/\(Int($0.carbs)) г; вода цель \(String(format: "%.1f", $0.waterLiters)) л; последние приемы: \(mealSummary.isEmpty ? "нет записей" : mealSummary)" } ?? "Нет цели",
            recentTrend: "\(trendSummary); шаги \(Int(latestMetric?.steps ?? 0)); вода \(String(format: "%.1f", latestMetric?.waterLiters ?? 0)) л; сон \(String(format: "%.1f", latestMetric?.sleepHours ?? 0)) ч; последние тренировки: \(workoutSummary.isEmpty ? "нет записей" : workoutSummary)",
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
    var image: UIImage? = nil
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
                if let image = bubble.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 170, height: 126)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                Text(bubble.text)
                    .font(.system(size: 17, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 270, alignment: bubble.role == .user ? .trailing : .leading)
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
    var size: CGFloat = 118

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Circle().fill(AppColors.purple.opacity(0.12)).padding(8)
            Image(systemName: "sparkles")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.white, AppColors.purple], startPoint: .top, endPoint: .bottom))
        }
        .frame(width: size, height: size)
        .fixedSize()
    }
}

private struct AIAvatarDot: View {
    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(AppColors.purple)
            .frame(width: 42, height: 42)
            .background(Circle().fill(Color.white.opacity(0.08)).overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)))
    }
}
