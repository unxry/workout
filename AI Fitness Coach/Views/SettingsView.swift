import LocalAuthentication
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: LocalDataStore

    @State private var activeSheet: ProfileSheet?
    @State private var statusMessage = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Профиль")

                profileCard
                statsGrid
                goalSection
                settingsSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 144)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .myData:
                ProfileDataEditSheet(profile: profile, status: $statusMessage) { updated in
                    store.updateProfile { profile in
                        profile.name = updated.name
                        profile.birthDate = updated.birthDate
                        profile.sexRawValue = updated.sexRawValue
                        profile.heightCm = updated.heightCm
                        profile.currentWeightKg = updated.currentWeightKg
                    }
                }
            case .goal:
                GoalEditSheet(profile: profile, status: $statusMessage) { updated in
                    store.updateProfile { profile in
                        profile.goalRawValue = updated.goalRawValue
                        profile.currentWeightKg = updated.currentWeightKg
                        profile.targetWeightKg = updated.targetWeightKg
                        profile.goalStartWeightKg = updated.goalStartWeightKg
                        profile.desiredGoalDate = updated.desiredGoalDate
                        profile.activityLevel = updated.activityLevel
                    }
                }
            case .health:
                HealthPermissionsSheet(status: $statusMessage)
            case .notifications:
                NotificationsSettingsSheet(status: $statusMessage)
            }
        }
        .alert("Статус", isPresented: Binding(get: { !statusMessage.isEmpty }, set: { if !$0 { statusMessage = "" } })) {
            Button("OK") { statusMessage = "" }
        } message: {
            Text(statusMessage)
        }
    }

    private var profile: UserProfile {
        store.profile ?? UserProfile(
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
        NutritionCalculator.goalProgress(for: profile)
    }

    private var targets: NutritionTargets {
        NutritionCalculator.targets(for: profile)
    }

    private var profileCard: some View {
        PremiumCard(padding: 20, radius: 22) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    profileTextBlock
                        .frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    profileProgressCircle(size: 88)
                }

                VStack(alignment: .leading, spacing: 16) {
                    profileTextBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 14) {
                        profileProgressCircle(size: 76)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Цель выполнена на \(Int((progress * 100).rounded()))%")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            GradientProgressBar(progress: progress, tint: AppColors.purple, height: 5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
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

            Text("Осталось: \(String(format: "%.1f", NutritionCalculator.remainingWeight(for: profile))) кг")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.green)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileProgressCircle(size: CGFloat) -> some View {
        CircularProgress(progress: progress, tint: AppColors.purple, lineWidth: size > 80 ? 8 : 7, size: size) {
            VStack(spacing: 2) {
                Text("\(Int((progress * 100).rounded()))%")
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
                            Text(targets.isDateTooAggressive ? "Безопасный темп вместо слишком ранней даты" : "Рекомендованный темп")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppColors.green)
                    }
                    GradientProgressBar(progress: progress, tint: AppColors.green, height: 8)
                    HStack {
                        Text("Осталось: ")
                            .foregroundColor(AppColors.secondaryText)
                        + Text("\(String(format: "%.1f", NutritionCalculator.remainingWeight(for: profile))) кг")
                            .foregroundColor(.white)
                        Spacer()
                        Text("Ориентировочная дата: ")
                            .foregroundColor(AppColors.secondaryText)
                        + Text(targets.goalDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(AppColors.purple)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)

                    if let message = targets.safetyMessage {
                        Text(message)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.yellow)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
        case .health:
            nil
        case .notifications:
            nil
        default:
            nil
        }
    }

    private var exportRows: [String] {
        [
            "Профиль: \(profile.name), \(profile.currentWeightKg) кг → \(profile.targetWeightKg) кг",
            "Приемов пищи: \(store.meals.count)",
            "Записей веса/воды: \(store.metrics.count)",
            "Тренировок: \(store.workouts.count)"
        ]
    }

    private func deleteAllData() {
        store.deleteDiaryProgressAndWorkouts()
        statusMessage = "Дневник, прогресс и тренировки удалены. Профиль сохранен."
    }
}

enum ProfileSheet: String, CaseIterable, Identifiable {
    case myData
    case goal
    case notifications
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .myData: "Мои данные"
        case .goal: "Цель"
        case .notifications: "Уведомления"
        case .health: "Здоровье и разрешения"
        }
    }

    var subtitle: String {
        switch self {
        case .myData: "Рост, вес, возраст, пол"
        case .goal: "Тип цели, целевой вес, темп"
        case .notifications: "Напоминания и оповещения"
        case .health: "HealthKit, камера, фото, уведомления"
        }
    }

    var icon: String {
        switch self {
        case .myData: "person.fill"
        case .goal: "target"
        case .notifications: "bell"
        case .health: "heart"
        }
    }

    var tint: Color {
        switch self {
        case .myData: AppColors.purple
        case .goal: AppColors.green
        case .notifications: AppColors.yellow
        case .health: AppColors.blue
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
                        .foregroundStyle(AppColors.secondaryText)
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
                    await appState.notifications.scheduleDefaultReminders()
                    let count = await appState.notifications.pendingReminderCount()
                    status = "Уведомления включены: запланировано \(count)"
                } else {
                    status = "Разрешение не выдано"
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }
}

private struct ProfileDataEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    @Binding var status: String
    let onSave: (ProfileDataUpdate) -> Void

    @State private var name: String
    @State private var birthDate: Date
    @State private var sexRawValue: String
    @State private var heightCm: String
    @State private var currentWeightKg: String
    @State private var validation = ""

    init(profile: UserProfile, status: Binding<String>, onSave: @escaping (ProfileDataUpdate) -> Void) {
        self.profile = profile
        self._status = status
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _birthDate = State(initialValue: profile.birthDate)
        _sexRawValue = State(initialValue: profile.sexRawValue)
        _heightCm = State(initialValue: String(format: "%.1f", profile.heightCm))
        _currentWeightKg = State(initialValue: String(format: "%.1f", profile.currentWeightKg))
    }

    var body: some View {
        FoodFormShell(title: "Мои данные") {
            PremiumTextField(placeholder: "Имя", text: $name)
            DatePicker("Дата рождения", selection: $birthDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .foregroundStyle(.white)
                .tint(AppColors.purple)
            Picker("Пол", selection: $sexRawValue) {
                ForEach(BiologicalSex.allCases) { sex in
                    Text(sex.rawValue).tag(sex.rawValue)
                }
            }
            .pickerStyle(.segmented)
            PremiumTextField(placeholder: "Рост, см", text: $heightCm, keyboard: .decimalPad)
            PremiumTextField(placeholder: "Текущий вес, кг", text: $currentWeightKg, keyboard: .decimalPad)

            if !validation.isEmpty {
                Text(validation)
                    .foregroundStyle(AppColors.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PremiumButton(title: "Сохранить", icon: "checkmark", tint: AppColors.green) {
                guard let update = validate() else { return }
                onSave(update)
                status = "Профиль обновлен"
                dismiss()
            }
        }
    }

    private func validate() -> ProfileDataUpdate? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedHeight = settingsNumber(heightCm)
        let parsedWeight = settingsNumber(currentWeightKg)
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0

        if trimmedName.isEmpty {
            validation = "Имя не должно быть пустым."
            return nil
        }
        if !(120...230).contains(parsedHeight) {
            validation = "Укажите реальный рост: 120-230 см."
            return nil
        }
        if !(35...250).contains(parsedWeight) {
            validation = "Укажите реальный вес: 35-250 кг."
            return nil
        }
        if !(10...100).contains(age) {
            validation = "Проверьте дату рождения."
            return nil
        }
        validation = ""
        return ProfileDataUpdate(
            name: trimmedName,
            birthDate: birthDate,
            sexRawValue: sexRawValue,
            heightCm: parsedHeight,
            currentWeightKg: parsedWeight
        )
    }
}

private struct GoalEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    @Binding var status: String
    let onSave: (GoalDataUpdate) -> Void

    @State private var goalRawValue: String
    @State private var goalStartWeightKg: String
    @State private var currentWeightKg: String
    @State private var targetWeightKg: String
    @State private var desiredGoalDate: Date
    @State private var activityLevel: String
    @State private var validation = ""
    @State private var confirmReset = false

    init(profile: UserProfile, status: Binding<String>, onSave: @escaping (GoalDataUpdate) -> Void) {
        self.profile = profile
        self._status = status
        self.onSave = onSave
        _goalRawValue = State(initialValue: profile.goalRawValue)
        _goalStartWeightKg = State(initialValue: String(format: "%.1f", profile.goalStartWeightKg))
        _currentWeightKg = State(initialValue: String(format: "%.1f", profile.currentWeightKg))
        _targetWeightKg = State(initialValue: String(format: "%.1f", profile.targetWeightKg))
        _desiredGoalDate = State(initialValue: profile.desiredGoalDate ?? NutritionCalculator.targets(for: profile).goalDate)
        _activityLevel = State(initialValue: String(format: "%.2f", profile.activityLevel))
    }

    var body: some View {
        FoodFormShell(title: "Изменить цель") {
            Picker("Цель", selection: $goalRawValue) {
                ForEach(FitnessGoal.allCases) { goal in
                    Text(goal.rawValue).tag(goal.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.purple)

            PremiumTextField(placeholder: "Стартовый вес цели, кг", text: $goalStartWeightKg, keyboard: .decimalPad)
            PremiumTextField(placeholder: "Текущий вес, кг", text: $currentWeightKg, keyboard: .decimalPad)
            PremiumTextField(placeholder: "Целевой вес, кг", text: $targetWeightKg, keyboard: .decimalPad)
            DatePicker("Хочу достичь к", selection: $desiredGoalDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .foregroundStyle(.white)
                .tint(AppColors.purple)
            PremiumTextField(placeholder: "Активность TDEE множитель", text: $activityLevel, keyboard: .decimalPad)

            let preview = previewProfile
            let targets = NutritionCalculator.targets(for: preview)
            PremiumCard(padding: 14, radius: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Новые цели")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(Int(targets.calories)) ккал • Б \(Int(targets.protein)) г • Ж \(Int(targets.fat)) г • У \(Int(targets.carbs)) г")
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Нужный темп: \(signedWeight(targets.requiredWeeklyWeightDelta)) кг/нед.")
                        .foregroundStyle(AppColors.secondaryText)
                    Text("Плановый темп: \(signedWeight(targets.weeklyWeightDelta)) кг/нед.")
                        .foregroundStyle(targets.isDateTooAggressive ? AppColors.yellow : AppColors.green)
                    Text("Ориентировочная дата: \(targets.goalDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(AppColors.purple)
                    if let message = targets.safetyMessage {
                        Text(message)
                            .foregroundStyle(AppColors.yellow)
                            .fixedSize(horizontal: false, vertical: true)
                        PremiumButton(title: "Использовать рекомендованную дату", icon: "calendar.badge.checkmark", tint: AppColors.purple) {
                            desiredGoalDate = targets.recommendedGoalDate
                        }
                    }
                }
            }

            if !validation.isEmpty {
                Text(validation)
                    .foregroundStyle(AppColors.yellow)
            }

            PremiumButton(title: "Сохранить цель", icon: "checkmark", tint: AppColors.green) {
                guard let update = validate() else { return }
                onSave(update)
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
                let current = settingsNumber(currentWeightKg)
                onSave(GoalDataUpdate(goalRawValue: FitnessGoal.maintenance.rawValue, goalStartWeightKg: current, currentWeightKg: current, targetWeightKg: current, desiredGoalDate: nil, activityLevel: settingsNumber(activityLevel)))
                status = "Цель сброшена"
                dismiss()
            }
            Button("Отмена", role: .cancel) { confirmReset = false }
        }
    }

    private var previewProfile: UserProfile {
        UserProfile(
            id: profile.id,
            name: profile.name,
            birthDate: profile.birthDate,
            sex: profile.sex,
            heightCm: profile.heightCm,
            currentWeightKg: settingsNumber(currentWeightKg),
            targetWeightKg: settingsNumber(targetWeightKg),
            goalStartWeightKg: settingsNumber(goalStartWeightKg),
            desiredGoalDate: desiredGoalDate,
            goal: FitnessGoal(rawValue: goalRawValue) ?? profile.goal,
            activityLevel: settingsNumber(activityLevel),
            trainingDaysPerWeek: profile.trainingDaysPerWeek,
            preferredMealsPerDay: profile.preferredMealsPerDay,
            sleepTime: profile.sleepTime,
            wakeTime: profile.wakeTime,
            allergies: profile.allergies,
            excludedFoods: profile.excludedFoods
        )
    }

    private func validate() -> GoalDataUpdate? {
        let start = settingsNumber(goalStartWeightKg)
        let current = settingsNumber(currentWeightKg)
        let target = settingsNumber(targetWeightKg)
        let activity = settingsNumber(activityLevel)
        if !(35...250).contains(start) {
            validation = "Стартовый вес должен быть 35-250 кг."
            return nil
        }
        if !(35...250).contains(current) {
            validation = "Текущий вес должен быть 35-250 кг."
            return nil
        }
        if !(35...250).contains(target) {
            validation = "Целевой вес должен быть 35-250 кг."
            return nil
        }
        if !(1.2...2.2).contains(activity) {
            validation = "Активность должна быть примерно 1.2-2.2."
            return nil
        }
        validation = ""
        return GoalDataUpdate(goalRawValue: goalRawValue, goalStartWeightKg: start, currentWeightKg: current, targetWeightKg: target, desiredGoalDate: desiredGoalDate, activityLevel: activity)
    }

    private func signedWeight(_ value: Double) -> String {
        String(format: "%+.2f", value)
    }
}

private struct ProfileDataUpdate {
    let name: String
    let birthDate: Date
    let sexRawValue: String
    let heightCm: Double
    let currentWeightKg: Double
}

private struct GoalDataUpdate {
    let goalRawValue: String
    let goalStartWeightKg: Double
    let currentWeightKg: Double
    let targetWeightKg: Double
    let desiredGoalDate: Date?
    let activityLevel: Double
}

private func settingsNumber(_ text: String) -> Double {
    Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
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
