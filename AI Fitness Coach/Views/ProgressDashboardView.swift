import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: LocalDataStore

    @State private var selectedTab = "Сегодня"
    @State private var selectedExercise: WorkoutExercise?
    @State private var showActiveWorkout = false
    @State private var showPrograms = false
    @State private var showCreate = false
    @State private var showMuscleFocus = false
    @State private var showTimer = false
    @State private var showHistory = false

    private let tabs = ["Сегодня", "План", "История", "Статистика"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Тренировки") {
                    appState.selectedTab = .coach
                }

                tabSelector
                todayWorkoutCard
                workoutPlan
                quickActions
                recentWorkouts
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 118)
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailSheet(exercise: exercise) {
                showActiveWorkout = true
            }
        }
        .fullScreenCover(isPresented: $showActiveWorkout) {
            ActiveWorkoutView(exercises: workoutPlanData) { log in
                store.addWorkout(log)
                Haptics.success()
            }
        }
        .sheet(isPresented: $showPrograms) {
            SimpleInfoSheet(title: "Готовые программы", rows: [
                "Full Body • Новичок • 3 дня/нед • 45 мин",
                "Upper/Lower • Средний • 4 дня/нед • 55 мин",
                "Push Pull Legs • Продвинутый • 6 дней/нед",
                "Home Workout • Дом • без оборудования",
                "Muscle Gain • рост силы и массы",
                "Fat Loss • дефицит + силовые"
            ])
        }
        .sheet(isPresented: $showCreate) {
            CreateWorkoutSheet { title in
                store.addWorkout(WorkoutLog(title: title, durationMinutes: 45, calories: 360, notes: "Создано вручную"))
            }
        }
        .sheet(isPresented: $showMuscleFocus) {
            SimpleInfoSheet(title: "Фокус мышц", rows: [
                "Грудь: жим лежа, разводка, отжимания",
                "Спина: тяга верхнего блока, горизонтальная тяга",
                "Плечи: жим гантелей, махи в стороны",
                "Ноги: присед, выпады, жим ногами",
                "Пресс: планка, скручивания"
            ])
        }
        .sheet(isPresented: $showTimer) {
            RestTimerSheet {
                showTimer = false
            }
        }
        .sheet(isPresented: $showHistory) {
            SimpleInfoSheet(title: "История тренировок", rows: historyRows)
        }
    }

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 28) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        Haptics.tap()
                        selectedTab = tab
                        if tab == "История" { showHistory = true }
                    } label: {
                        VStack(spacing: 11) {
                            Text(tab)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(selectedTab == tab ? AppColors.purple : AppColors.secondaryText)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Rectangle()
                                .fill(selectedTab == tab ? AppColors.purple : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 18)
        }
    }

    private var todayWorkoutCard: some View {
        PremiumCard(padding: 22, radius: 22) {
            ZStack(alignment: .trailing) {
                MuscleVisual()
                    .frame(width: 160, height: 218)
                    .offset(x: 4, y: 10)
                    .opacity(0.92)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Сегодняшняя тренировка")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                    Text("Верх тела")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 10) {
                        workoutPill(icon: "clock", text: "45–60 мин")
                        workoutPill(icon: "dumbbell", text: "6 упражнений")
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Калории (оценка)")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                        Text("320 – 450 ккал")
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(AppColors.purple)
                    }
                    HStack {
                        Spacer(minLength: 120)
                        PremiumButton(title: "Начать тренировку", icon: "play.fill", tint: AppColors.purple) {
                            showActiveWorkout = true
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 250)
        }
    }

    private var workoutPlan: some View {
        PremiumCard(padding: 18, radius: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("План на сегодня")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Изменить план") {
                        Haptics.tap()
                        showPrograms = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.purple)
                }
                ForEach(workoutPlanData) { exercise in
                    Button {
                        Haptics.tap()
                        selectedExercise = exercise
                    } label: {
                        WorkoutExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickActions: some View {
        PremiumCard(padding: 18, radius: 22) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Быстрые действия")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    quickWorkout(icon: "plus", title: "Создать\nтренировку") { showCreate = true }
                    quickWorkout(icon: "clipboard", title: "Готовые\nпрограммы") { showPrograms = true }
                    quickWorkout(icon: "scope", title: "Фокус\nмышц") { showMuscleFocus = true }
                    quickWorkout(icon: "stopwatch", title: "Таймер\nотдыха") { showTimer = true }
                }
            }
        }
    }

    private var recentWorkouts: some View {
        PremiumCard(padding: 18, radius: 22) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Последние тренировки")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("См. все") { showHistory = true }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.purple)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                    IconBadge(systemName: "calendar", tint: AppColors.secondaryText, size: 46)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.workouts.first?.title ?? "Верх тела")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("5 августа 2026 • 18:40")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColors.mutedText)
                    }
                    HStack(spacing: 8) {
                        stat("6", "Упражнений")
                        stat("42:10", "Длительность")
                        stat("410", "ккал")
                    }
                }
            }
        }
    }

    private var historyRows: [String] {
        if store.workouts.isEmpty {
            return ["Верх тела • 42:10 • 6 упражнений • 410 ккал"]
        }
        return store.workouts.map { "\($0.title) • \($0.durationMinutes) мин • \(Int($0.calories)) ккал" }
    }

    private func workoutPill(icon: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.purple)
            Text(text)
                .foregroundStyle(.white)
        }
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.09)))
    }

    private func quickWorkout(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 12) {
                IconBadge(systemName: icon, tint: AppColors.purple, size: 52)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.050))
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutExercise: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
    let subtitle: String
    let weight: String
    let emoji: String
    let instructions: [String]
}

private let workoutPlanData: [WorkoutExercise] = [
    WorkoutExercise(number: 1, title: "Жим штанги лежа", subtitle: "4 подхода • 8–10 повторений", weight: "70 кг", emoji: "🏋️", instructions: ["Ляг на скамью и сведи лопатки.", "Поставь стопы плотно.", "Опусти штангу к нижней части груди.", "Выжми вверх без отрыва таза."]),
    WorkoutExercise(number: 2, title: "Тяга верхнего блока", subtitle: "4 подхода • 10–12 повторений", weight: "60 кг", emoji: "💪", instructions: ["Сядь ровно.", "Тяни рукоять к верхней груди.", "Не запрокидывай корпус назад."]),
    WorkoutExercise(number: 3, title: "Жим гантелей на наклонной", subtitle: "3 подхода • 10–12 повторений", weight: "22 кг", emoji: "🏋️", instructions: ["Сохраняй угол скамьи 30–45°.", "Опускай гантели контролируемо.", "Не своди гантели ударом."]),
    WorkoutExercise(number: 4, title: "Тяга горизонтального блока", subtitle: "3 подхода • 10–12 повторений", weight: "55 кг", emoji: "🧲", instructions: ["Тяни локти назад.", "Пауза в пике.", "Не округляй спину."]),
    WorkoutExercise(number: 5, title: "Подъём гантелей в стороны", subtitle: "3 подхода • 12–15 повторений", weight: "8 кг", emoji: "🙆", instructions: ["Локти мягко согнуты.", "Поднимай до уровня плеч.", "Не раскачивай корпус."]),
    WorkoutExercise(number: 6, title: "Разгибание рук на блоке", subtitle: "3 подхода • 12–15 повторений", weight: "45 кг", emoji: "💪", instructions: ["Зафиксируй локти.", "Разгибай до полного сокращения.", "Возвращай вес медленно."])
]

private struct WorkoutExerciseRow: View {
    let exercise: WorkoutExercise

    var body: some View {
        HStack(spacing: 12) {
            Text("\(exercise.number)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.purple)
                .frame(width: 28, height: 28)
                .background(Circle().fill(AppColors.purple.opacity(0.13)))
            Text(exercise.emoji)
                .font(.system(size: 30))
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.075)))
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                Text(exercise.subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
            }
            .layoutPriority(1)
            Spacer()
            Text(exercise.weight)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            Image(systemName: "chevron.right")
                .foregroundStyle(AppColors.mutedText)
                .fixedSize()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }
}

private struct MuscleVisual: View {
    var body: some View {
        ZStack {
            Capsule().fill(AppColors.purple.opacity(0.16)).frame(width: 76, height: 190).blur(radius: 20)
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 142, weight: .ultraLight))
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.18), AppColors.purple.opacity(0.92)], startPoint: .top, endPoint: .bottom))
            Circle().fill(AppColors.purple.opacity(0.35)).frame(width: 72, height: 72).blur(radius: 24).offset(x: -18, y: -50)
        }
    }
}

private struct ExerciseDetailSheet: View {
    let exercise: WorkoutExercise
    let start: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(exercise.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 13) {
                            Text(exercise.emoji)
                                .font(.system(size: 76))
                                .frame(maxWidth: .infinity)
                            Text("Техника выполнения")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(.white)
                            ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                                Text("\(index + 1). \(step)")
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            Text("Рабочие мышцы: грудь, трицепс, передняя дельта")
                                .foregroundStyle(.white.opacity(0.86))
                            Text("Ошибки: локти слишком широко, отрыв таза, удар весом.")
                                .foregroundStyle(AppColors.secondaryText)
                            Text("Темп: 2 сек вниз • 1 сек вверх. Дыхание: вдох вниз, выдох вверх.")
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                    PremiumButton(title: "Начать подход", icon: "play.fill", tint: AppColors.purple) {
                        dismiss()
                        start()
                    }
                }
                .padding(22)
            }
        }
    }
}

private struct ActiveWorkoutView: View {
    let exercises: [WorkoutExercise]
    let onFinish: (WorkoutLog) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var engine: WorkoutFlowEngine
    @State private var phaseBeforePause: WorkoutPhase = .runningExercise
    @State private var weight = "70"
    @State private var reps = "10"
    @State private var showRest = false
    @State private var confirmStop = false

    init(exercises: [WorkoutExercise], onFinish: @escaping (WorkoutLog) -> Void) {
        self.exercises = exercises
        self.onFinish = onFinish
        _engine = State(initialValue: WorkoutFlowEngine(exerciseCount: exercises.count))
    }

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("\(engine.exerciseIndex + 1) / \(exercises.count) exercises")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.purple)
                    Spacer()
                    Button("Закрыть") { confirmStop = true }
                        .foregroundStyle(AppColors.secondaryText)
                }
                GradientProgressBar(progress: Double(engine.exerciseIndex + 1) / Double(exercises.count), tint: AppColors.purple, height: 7)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(formatDuration(engine.elapsed))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Text(exercises[engine.exerciseIndex].title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Set \(engine.setIndex) / \(engine.setsPerExercise)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
                PremiumTextField(placeholder: "Weight kg", text: $weight, keyboard: .decimalPad)
                PremiumTextField(placeholder: "Reps", text: $reps, keyboard: .numberPad)
                PremiumCard {
                    Text("Прошлая тренировка: 70×10, 70×10, 70×9, 65×11\nЕсли техника была хорошей, попробуй 72.5 кг.")
                        .foregroundStyle(AppColors.secondaryText)
                }
                PremiumButton(title: "Завершить подход", icon: "checkmark", tint: AppColors.green) {
                    finishSet()
                }
                HStack(spacing: 10) {
                    Button(engine.phase == .paused ? "Resume" : "Pause") {
                        if engine.phase == .paused {
                            engine.resume(previousPhase: phaseBeforePause)
                        } else {
                            phaseBeforePause = engine.phase
                            engine.pause()
                        }
                    }
                    .accessibilityIdentifier(engine.phase == .paused ? "activeWorkout.resume" : "activeWorkout.pause")
                    Button("Finish") { completeWorkout() }
                        .accessibilityIdentifier("activeWorkout.finish")
                }
                .buttonStyle(.bordered)
                .tint(AppColors.purple)
                Spacer()
            }
            .padding(22)
        }
        .sheet(isPresented: $showRest) {
            RestTimerSheet {
                engine.skipRest()
                showRest = false
            }
        }
        .confirmationDialog("Завершить тренировку?", isPresented: $confirmStop) {
            Button("Завершить", role: .destructive) { dismiss() }
            Button("Отмена", role: .cancel) { confirmStop = false }
        }
    }

    private func finishSet() {
        engine.finishSet()
        if engine.phase == .resting {
            showRest = true
        } else if engine.phase == .completed {
            completeWorkout()
        }
    }

    private func completeWorkout() {
        let minutes = max(1, Int(engine.elapsed / 60))
        onFinish(WorkoutLog(title: "Верх тела", durationMinutes: minutes, calories: 410, notes: "\(exercises.count) упражнений • \(engine.setsPerExercise) подхода"))
        dismiss()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

private struct RestTimerSheet: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var countdown = RestCountdown(duration: 90)

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(spacing: 24) {
                Text("Rest")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = countdown.remaining(now: context.date)
                    CircularProgress(progress: remaining / countdown.duration, tint: AppColors.purple, lineWidth: 12, size: 180) {
                        Text(String(format: "%02d:%02d", Int(remaining) / 60, Int(remaining) % 60))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .onChange(of: Int(remaining)) { value in
                        if value <= 0 {
                            Haptics.success()
                            onComplete()
                            dismiss()
                        }
                    }
                }
                HStack {
                    Button("+30 sec") { countdown.add(30) }
                        .accessibilityIdentifier("rest.add30")
                    Button(countdown.isPaused ? "Resume" : "Pause") {
                        countdown.isPaused ? countdown.resume() : countdown.pause()
                    }
                    .accessibilityIdentifier(countdown.isPaused ? "rest.resume" : "rest.pause")
                    Button("Skip") {
                        onComplete()
                        dismiss()
                    }
                    .accessibilityIdentifier("rest.skip")
                }
                .buttonStyle(.bordered)
                .tint(AppColors.purple)
            }
            .padding(22)
        }
        .presentationDetents([.medium])
    }
}

private struct CreateWorkoutSheet: View {
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Моя тренировка"

    var body: some View {
        FoodFormShell(title: "Создать тренировку") {
            PremiumTextField(placeholder: "Название", text: $title)
            Text("Дни: Пн • Ср • Пт\nУпражнения: жим, тяга, присед\nSets/Reps/Rest можно отредактировать в плане.")
                .foregroundStyle(AppColors.secondaryText)
            PremiumButton(title: "Сохранить", icon: "checkmark", tint: AppColors.green) {
                onSave(title)
                dismiss()
            }
        }
    }
}
