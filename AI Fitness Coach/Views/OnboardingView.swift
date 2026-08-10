import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: LocalDataStore

    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var sex: BiologicalSex = .male
    @State private var height = 178.0
    @State private var weight = 82.0
    @State private var targetWeight = 76.0
    @State private var goal: FitnessGoal = .fatLoss
    @State private var activity = 1.45
    @State private var trainings = 3
    @State private var meals = 4
    @State private var allergies = ""
    @State private var excludedFoods = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Fitness Coach")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Настроим личного тренера, который будет жить на твоем iPhone и адаптировать стратегию каждый день.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.62))
                }

                GlassPanel {
                    VStack(spacing: 18) {
                        TextField("Имя", text: $name)
                            .textFieldStyle(.plain)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        DatePicker("Дата рождения", selection: $birthDate, displayedComponents: .date)
                        Picker("Пол", selection: $sex) {
                            ForEach(BiologicalSex.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }

                        Picker("Цель", selection: $goal) {
                            ForEach(FitnessGoal.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }

                        sliderRow("Рост", value: $height, range: 140...220, suffix: "см")
                        sliderRow("Вес", value: $weight, range: 40...160, suffix: "кг")
                        sliderRow("Цель", value: $targetWeight, range: 40...160, suffix: "кг")

                        Stepper("Тренировки: \(trainings) / нед", value: $trainings, in: 0...7)
                        Stepper("Приемы пищи: \(meals)", value: $meals, in: 2...7)

                        TextField("Аллергии", text: $allergies)
                            .textFieldStyle(.roundedBorder)
                        TextField("Исключенные продукты", text: $excludedFoods)
                            .textFieldStyle(.roundedBorder)
                    }
                    .tint(Color.purpleAccent)
                    .foregroundStyle(.white)
                }

                Button {
                    createProfile()
                } label: {
                    Text("Создать план")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(colors: [Color.purpleAccent, Color.blueAccent], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.createPlan")
            }
            .padding(22)
            .padding(.top, 32)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(suffix)")
                    .foregroundStyle(.white.opacity(0.65))
            }
            Slider(value: value, in: range)
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            name: name.isEmpty ? "Ты" : name,
            birthDate: birthDate,
            sex: sex,
            heightCm: height,
            currentWeightKg: weight,
            targetWeightKg: targetWeight,
            goal: goal,
            activityLevel: activity,
            trainingDaysPerWeek: trainings,
            preferredMealsPerDay: meals,
            sleepTime: .now,
            wakeTime: .now,
            allergies: allergies,
            excludedFoods: excludedFoods
        )
        store.createProfile(profile, initialWeight: weight)
    }
}
