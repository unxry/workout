import LocalAuthentication
import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \DailyMetric.date, order: .reverse) private var metrics: [DailyMetric]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var workouts: [WorkoutLog]

    @State private var activeSheet: ProfileSheet?
    @State private var statusMessage = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Профиль") {
                    appState.selectedTab = .coach
                }

                profileCard
                statsGrid
                goalSection
                settingsSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 118)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .myData:
                ProfileDataEditSheet(profile: profile, status: $statusMessage)
            case .goal:
                GoalEditSheet(profile: profile, status: $statusMessage)
            case .nutrition:
                SimpleInfoSheet(title: "Питание", rows: ["Аллергии: \(profile.allergies.isEmpty ? "не указаны" : profile.allergies)", "Исключенные продукты: \(profile.excludedFoods.isEmpty ? "нет" : profile.excludedFoods)", "Приемов пищи: \(profile.preferredMealsPerDay)"])
            case .training:
                SimpleInfoSheet(title: "Тренировки", rows: ["Опыт: средний", "Дней в неделю: \(profile.trainingDaysPerWeek)", "Оборудование: зал + дом"])
            case .health:
                HealthPermissionsSheet(status: $statusMessage)
            case .notifications:
                NotificationsSettingsSheet(status: $statusMessage)
            case .ai:
                AliceAISettingsSheet()
                    .environmentObject(appState)
            case .security:
                SecuritySheet(status: $statusMessage)
            case .privacy:
                PrivacySheet(exportRows: exportRows, deleteAll: deleteAllData)
            case .about:
                SimpleInfoSheet(title: "О приложении", rows: ["AI Fitness Coach", "Версия 1.0.0", "Локальные данные + Yandex AI", "Поддержка: GitHub unxry/workout"])
            }
        }
        .alert("Статус", isPresented: Binding(get: { !statusMessage.isEmpty }, set: { if !$0 { statusMessage = "" } })) {
            Button("OK") { statusMessage = "" }
        } message: {
            Text(statusMessage)
        }
    }

    private var profile: UserProfile {
        profiles.first ?? UserProfile(
            name: "Александр",
            birthDate: Calendar.current.date(byAdding: .year, value: -28, to: .now) ?? .now,
            sex: .male,
            heightCm: 182,
            currentWeightKg: 85.4,
            targetWeightKg: 75.0,
            goal: .fatLoss,
            activityLevel: 1.55,
            trainingDaysPerWeek: 4,
            preferredMealsPerDay: 4,
            sleepTime: .now,
            wakeTime: .now,
            allergies: "",
            excludedFoods: ""
        )
    }

    private var progress: Double {
        let start = max(profile.currentWeightKg + 8, profile.currentWeightKg)
        let total = abs(start - profile.targetWeightKg)
        guard total > 0 else { return 0.45 }
        return min(max(abs(start - profile.currentWeightKg) / total, 0.0), 1.0)
    }

    private var profileCard: some View {
        PremiumCard(padding: 20, radius: 22) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    profileAvatar(size: 104)
                    profileTextBlock
                        .frame(minWidth: 165, maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    profileProgressCircle(size: 88)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        profileAvatar(size: 92)
                        profileTextBlock
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                    }
                    HStack(spacing: 14) {
                        profileProgressCircle(size: 76)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Цель выполнена на 45%")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            GradientProgressBar(progress: 0.45, tint: AppColors.purple, height: 5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func profileAvatar(size: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(colors: [Color.white.opacity(0.18), AppColors.purple.opacity(0.28)], startPoint: .top, endPoint: .bottom)
                )
                .overlay(Circle().stroke(AppColors.purple, lineWidth: 3))
                .frame(width: size, height: size)
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.52, weight: .regular))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: size - 10, height: size - 10)
                .background(Circle().fill(Color.black.opacity(0.28)))
            Button {
                statusMessage = "Выбор фото профиля будет открыт на iPhone."
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.purple)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppColors.panelDeep).overlay(Circle().stroke(AppColors.purple, lineWidth: 2)))
            }
        }
        .frame(width: size, height: size)
        .fixedSize()
    }

    private var profileTextBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(profile.name.isEmpty ? "Александр" : profile.name)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)
                Button {
                    activeSheet = .myData
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(AppColors.purple)
                        .frame(width: 28, height: 28)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Text(profile.goal.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(AppColors.green.opacity(0.12)))

            HStack(spacing: 8) {
                Text("\(String(format: "%.1f", profile.currentWeightKg)) кг")
                    .foregroundStyle(.white)
                    .layoutPriority(1)
                Text("→")
                    .foregroundStyle(AppColors.secondaryText)
                Text("\(String(format: "%.1f", profile.targetWeightKg)) кг")
                    .foregroundStyle(AppColors.green)
                    .layoutPriority(1)
            }
            .font(.system(size: 21, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.84)

            Text("Прогресс: -4.6 кг")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.green)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileProgressCircle(size: CGFloat) -> some View {
        CircularProgress(progress: 0.45, tint: AppColors.purple, lineWidth: size > 80 ? 8 : 7, size: size) {
            VStack(spacing: 2) {
                Text("45%")
                    .font(.system(size: size > 80 ? 22 : 18, weight: .bold))
                    .foregroundStyle(AppColors.purple)
                    .lineLimit(1)
                Text("цели")
                    .font(.system(size: size > 80 ? 11 : 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .fixedSize()
    }

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ProfileStatCard(icon: "scalemass", value: "\(String(format: "%.1f", profile.currentWeightKg)) кг", label: "Текущий вес", tint: AppColors.purple)
            ProfileStatCard(icon: "target", value: "\(String(format: "%.1f", profile.targetWeightKg)) кг", label: "Целевой вес", tint: AppColors.green)
            ProfileStatCard(icon: "ruler", value: "\(Int(profile.heightCm)) см", label: "Рост", tint: AppColors.blue)
            ProfileStatCard(icon: "calendar", value: "\(profile.age) лет", label: "Возраст", tint: AppColors.orange)
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "МОЯ ЦЕЛЬ")
            PremiumCard(padding: 20, radius: 20) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        IconBadge(systemName: "chart.line.uptrend.xyaxis", tint: AppColors.green, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.goal.rawValue)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Умеренный дефицит")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Spacer()
                        Text("45%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppColors.green)
                    }
                    GradientProgressBar(progress: 0.45, tint: AppColors.green, height: 8)
                    HStack {
                        Text("Осталось: ")
                            .foregroundStyle(AppColors.secondaryText)
                        + Text("\(String(format: "%.1f", abs(profile.currentWeightKg - profile.targetWeightKg))) кг")
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Ориентировочная дата: ")
                            .foregroundStyle(AppColors.secondaryText)
                        + Text("15 нояб. 2026")
                            .foregroundStyle(AppColors.purple)
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "НАСТРОЙКИ")
            PremiumCard(padding: 0, radius: 20) {
                VStack(spacing: 0) {
                    ForEach(ProfileSheet.allCases) { sheet in
                        ProfileSettingsRow(sheet: sheet, status: status(for: sheet)) {
                            activeSheet = sheet
                        }
                        if sheet != ProfileSheet.allCases.last {
                            Divider().background(Color.white.opacity(0.07)).padding(.leading, 76)
                        }
                    }
                }
            }
        }
    }

    private func status(for sheet: ProfileSheet) -> String? {
        switch sheet {
        case .ai:
            appState.apiKeyStatus == .configured ? "Вкл." : nil
        case .security:
            "Вкл."
        case .about:
            "1.0.0"
        default:
            nil
        }
    }

    private var exportRows: [String] {
        [
            "Профиль: \(profile.name), \(profile.currentWeightKg) кг → \(profile.targetWeightKg) кг",
            "Приемов пищи: \(meals.count)",
            "Записей веса/воды: \(metrics.count)",
            "Тренировок: \(workouts.count)"
        ]
    }

    private func deleteAllData() {
        meals.forEach(modelContext.delete)
        metrics.forEach(modelContext.delete)
        workouts.forEach(modelContext.delete)
        try? modelContext.save()
        statusMessage = "Дневник, прогресс и тренировки удалены. Профиль сохранен."
    }
}

enum ProfileSheet: String, CaseIterable, Identifiable {
    case myData
    case goal
    case nutrition
    case training
    case health
    case notifications
    case ai
    case security
    case privacy
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .myData: "Мои данные"
        case .goal: "Цель"
        case .nutrition: "Питание"
        case .training: "Тренировки"
        case .health: "Здоровье и разрешения"
        case .notifications: "Уведомления"
        case .ai: "Алиса AI"
        case .security: "Безопасность"
        case .privacy: "Конфиденциальность"
        case .about: "О приложении"
        }
    }

    var subtitle: String {
        switch self {
        case .myData: "Рост, вес, возраст, пол"
        case .goal: "Тип цели, целевой вес, темп"
        case .nutrition: "Предпочтения, аллергии, исключенные продукты"
        case .training: "Опыт, оборудование, предпочтения"
        case .health: "HealthKit, доступы к данным"
        case .notifications: "Напоминания и оповещения"
        case .ai: "API key, Folder ID, проверка подключения"
        case .security: "Face ID, код-пароль"
        case .privacy: "Экспорт данных, удалить все данные"
        case .about: "Версия, поддержка, лицензии"
        }
    }

    var icon: String {
        switch self {
        case .myData: "person.fill"
        case .goal: "target"
        case .nutrition: "fork.knife"
        case .training: "dumbbell"
        case .health: "heart"
        case .notifications: "bell"
        case .ai: "sparkles"
        case .security: "lock"
        case .privacy: "shield"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .myData, .ai: AppColors.purple
        case .goal, .privacy: AppColors.green
        case .nutrition, .notifications: AppColors.yellow
        case .training: AppColors.purple
        case .health, .security: AppColors.blue
        case .about: AppColors.secondaryText
        }
    }
}

private struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        PremiumCard(padding: 14, radius: 16) {
            VStack(spacing: 9) {
                IconBadge(systemName: icon, tint: tint, size: 48)
                Text(value)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 122)
    }
}

private struct ProfileSettingsRow: View {
    let sheet: ProfileSheet
    let status: String?
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemName: sheet.icon, tint: sheet.tint, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(sheet.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(sheet.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                if let status {
                    Text(status)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(sheet == .security ? AppColors.purple : AppColors.secondaryText)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.mutedText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct HealthPermissionsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Binding var status: String

    var body: some View {
        SimpleInfoSheet(title: "Здоровье", rows: [
            "Apple Health: Steps, Weight, Active Energy, Workouts, Sleep",
            "Статус: \(status.isEmpty ? "не запрошено" : status)",
            "Нажми кнопку запроса доступа в профиле или открой настройки iOS."
        ])
        .task {
            do {
                try await appState.healthKit.requestAuthorization()
                status = "Доступ HealthKit запрошен"
            } catch {
                status = error.localizedDescription
            }
        }
    }
}

private struct NotificationsSettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Binding var status: String

    var body: some View {
        SimpleInfoSheet(title: "Уведомления", rows: [
            "Water reminders: каждые 2 часа",
            "Meal reminders: 09:00, 14:00, 19:00",
            "Workout reminders: 19:00",
            "Weight reminders: утром",
            "Sleep reminders: 23:00"
        ])
        .task {
            do {
                let allowed = try await appState.notifications.requestAuthorization()
                if allowed {
                    await appState.notifications.scheduleDailyCoachCheckIn()
                    status = "Уведомления включены"
                } else {
                    status = "Разрешение не выдано"
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }
}

private struct AliceAISettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var folderID = ""
    @State private var status = ""
    @State private var isTesting = false

    var body: some View {
        FoodFormShell(title: "Алиса AI") {
            Text("Yandex Cloud AI Studio")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text(appState.apiKeyStatus.isConfigured ? "Подключение настроено. Секреты хранятся только в Keychain." : "Не настроено. Алиса покажет понятную ошибку вместо фейкового ответа.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            SecureField("Yandex API Key", text: $key)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.075)))
            PremiumTextField(placeholder: "Folder ID", text: $folderID)
            Text("Модель выбирается автоматически: YandexGPT Lite. Фото-анализ не будет имитироваться, пока не подключен официальный vision endpoint.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Сохранить") {
                    let storedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? KeychainStore.shared.readYandexAPIKey() : key
                    let storedFolder = folderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? KeychainStore.shared.readYandexFolderID() : folderID
                    appState.saveAliceConfiguration(apiKey: storedKey, folderID: storedFolder)
                    key = ""
                    folderID = ""
                    status = appState.apiKeyStatus.isConfigured ? "Настройки сохранены" : "Заполните API Key и Folder ID"
                }
                Button("Удалить ключ") {
                    appState.deleteAliceConfiguration()
                    key = ""
                    folderID = ""
                    status = "Ключ удален"
                }
                Button(isTesting ? "Проверяю..." : "Проверить") {
                    Task {
                        let typedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                        let typedFolder = folderID.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !typedKey.isEmpty || !typedFolder.isEmpty {
                            appState.saveAliceConfiguration(
                                apiKey: typedKey.isEmpty ? KeychainStore.shared.readYandexAPIKey() : typedKey,
                                folderID: typedFolder.isEmpty ? KeychainStore.shared.readYandexFolderID() : typedFolder
                            )
                            key = ""
                            folderID = ""
                        }
                        isTesting = true
                        defer { isTesting = false }
                        do {
                            try await appState.aiClient.testConnection()
                            appState.refreshAliceStatus()
                            status = "Подключено"
                        } catch {
                            status = AIClientError.from(error).localizedDescription
                        }
                    }
                }
                .disabled(isTesting)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.purple)
            if !status.isEmpty {
                Text(status)
                    .foregroundStyle(status == "Подключено" ? AppColors.green : AppColors.yellow)
            }
            PremiumButton(title: "Готово", icon: "checkmark", tint: AppColors.green) {
                dismiss()
            }
        }
        .onAppear {
            appState.refreshAliceStatus()
        }
    }
}

private struct ProfileDataEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    @Binding var status: String
    @State private var validation = ""

    var body: some View {
        FoodFormShell(title: "Мои данные") {
            PremiumTextField(placeholder: "Имя", text: $profile.name)
            DatePicker("Дата рождения", selection: $profile.birthDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .foregroundStyle(.white)
                .tint(AppColors.purple)
            Picker("Пол", selection: $profile.sexRawValue) {
                ForEach(BiologicalSex.allCases) { sex in
                    Text(sex.rawValue).tag(sex.rawValue)
                }
            }
            .pickerStyle(.segmented)
            PremiumTextField(placeholder: "Рост, см", text: doubleBinding(\.heightCm), keyboard: .decimalPad)
            PremiumTextField(placeholder: "Текущий вес, кг", text: doubleBinding(\.currentWeightKg), keyboard: .decimalPad)

            if !validation.isEmpty {
                Text(validation)
                    .foregroundStyle(AppColors.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PremiumButton(title: "Сохранить", icon: "checkmark", tint: AppColors.green) {
                guard validate() else { return }
                profile.updatedAt = .now
                status = "Профиль обновлен"
                dismiss()
            }
        }
    }

    private func validate() -> Bool {
        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validation = "Имя не должно быть пустым."
            return false
        }
        if !(120...230).contains(profile.heightCm) {
            validation = "Укажите реальный рост: 120-230 см."
            return false
        }
        if !(35...250).contains(profile.currentWeightKg) {
            validation = "Укажите реальный вес: 35-250 кг."
            return false
        }
        if !(10...100).contains(profile.age) {
            validation = "Проверьте дату рождения."
            return false
        }
        validation = ""
        return true
    }

    private func doubleBinding(_ keyPath: ReferenceWritableKeyPath<UserProfile, Double>) -> Binding<String> {
        Binding(
            get: { String(format: "%.1f", profile[keyPath: keyPath]) },
            set: { profile[keyPath: keyPath] = Double($0.replacingOccurrences(of: ",", with: ".")) ?? profile[keyPath: keyPath] }
        )
    }
}

private struct GoalEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    @Binding var status: String
    @State private var validation = ""
    @State private var confirmReset = false

    var body: some View {
        FoodFormShell(title: "Изменить цель") {
            Picker("Цель", selection: $profile.goalRawValue) {
                ForEach(FitnessGoal.allCases) { goal in
                    Text(goal.rawValue).tag(goal.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.purple)

            PremiumTextField(placeholder: "Текущий вес, кг", text: doubleBinding(\.currentWeightKg), keyboard: .decimalPad)
            PremiumTextField(placeholder: "Целевой вес, кг", text: doubleBinding(\.targetWeightKg), keyboard: .decimalPad)
            PremiumTextField(placeholder: "Активность TDEE множитель", text: doubleBinding(\.activityLevel), keyboard: .decimalPad)

            let targets = NutritionCalculator.targets(for: profile)
            PremiumCard(padding: 14, radius: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Новые цели")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(Int(targets.calories)) ккал • Б \(Int(targets.protein)) г • Ж \(Int(targets.fat)) г • У \(Int(targets.carbs)) г")
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Ориентировочная дата: \(targets.goalDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(AppColors.purple)
                }
            }

            if !validation.isEmpty {
                Text(validation)
                    .foregroundStyle(AppColors.yellow)
            }

            PremiumButton(title: "Сохранить цель", icon: "checkmark", tint: AppColors.green) {
                guard validate() else { return }
                profile.updatedAt = .now
                status = "Цель обновлена"
                dismiss()
            }

            Button("Сбросить цель", role: .destructive) {
                confirmReset = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.orange)
        }
        .confirmationDialog("Сбросить цель?", isPresented: $confirmReset) {
            Button("Сбросить", role: .destructive) {
                profile.goalRawValue = FitnessGoal.maintenance.rawValue
                profile.targetWeightKg = profile.currentWeightKg
                profile.updatedAt = .now
                status = "Цель сброшена"
                dismiss()
            }
            Button("Отмена", role: .cancel) { confirmReset = false }
        }
    }

    private func validate() -> Bool {
        if !(35...250).contains(profile.currentWeightKg) {
            validation = "Текущий вес должен быть 35-250 кг."
            return false
        }
        if !(35...250).contains(profile.targetWeightKg) {
            validation = "Целевой вес должен быть 35-250 кг."
            return false
        }
        if !(1.2...2.2).contains(profile.activityLevel) {
            validation = "Активность должна быть примерно 1.2-2.2."
            return false
        }
        validation = ""
        return true
    }

    private func doubleBinding(_ keyPath: ReferenceWritableKeyPath<UserProfile, Double>) -> Binding<String> {
        Binding(
            get: { String(format: "%.1f", profile[keyPath: keyPath]) },
            set: { profile[keyPath: keyPath] = Double($0.replacingOccurrences(of: ",", with: ".")) ?? profile[keyPath: keyPath] }
        )
    }
}

private struct SecuritySheet: View {
    @Binding var status: String
    @State private var enabled = true

    var body: some View {
        FoodFormShell(title: "Безопасность") {
            Toggle("Защищать приложение Face ID", isOn: $enabled)
                .tint(AppColors.purple)
                .foregroundStyle(.white)
            Button("Проверить Face ID") {
                let context = LAContext()
                status = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? "Face ID доступен" : "Face ID недоступен на этом устройстве"
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.purple)
        }
    }
}

private struct PrivacySheet: View {
    let exportRows: [String]
    let deleteAll: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        FoodFormShell(title: "Конфиденциальность") {
            ForEach(exportRows, id: \.self) { row in
                Text(row)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Button("Экспорт JSON") { Haptics.success() }
                .buttonStyle(.bordered)
                .tint(AppColors.blue)
            Button("Экспорт CSV") { Haptics.success() }
                .buttonStyle(.bordered)
                .tint(AppColors.blue)
            Button("Удалить дневник и прогресс", role: .destructive) {
                confirmDelete = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.orange)
        }
        .confirmationDialog("Удалить данные?", isPresented: $confirmDelete) {
            Button("Удалить", role: .destructive) { deleteAll() }
            Button("Отмена", role: .cancel) { confirmDelete = false }
        } message: {
            Text("Профиль останется, дневник и прогресс будут очищены.")
        }
    }
}
