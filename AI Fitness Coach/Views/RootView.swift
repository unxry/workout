import SwiftData
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        ZStack {
            PremiumBackground()

            if profiles.first == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var showQuickActions = false
    @State private var quickMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch appState.selectedTab {
                case .home:
                    DashboardView()
                case .nutrition:
                    NutritionView()
                case .coach:
                    CoachView()
                case .progress:
                    ProgressDashboardView()
                case .profile:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PremiumTabBar(selected: $appState.selectedTab) {
                showQuickActions = true
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showQuickActions) {
            UniversalQuickActionSheet(
                addFood: {
                    showQuickActions = false
                    appState.selectedTab = .nutrition
                },
                addWater: {
                    modelContext.insert(DailyMetric(date: .now, weightKg: 85.4, waterLiters: 0.25))
                    try? modelContext.save()
                    quickMessage = "Вода добавлена: +250 мл"
                    showQuickActions = false
                },
                addWeight: {
                    modelContext.insert(DailyMetric(date: .now, weightKg: 85.4, waterLiters: 0))
                    try? modelContext.save()
                    quickMessage = "Вес записан"
                    showQuickActions = false
                },
                startWorkout: {
                    showQuickActions = false
                    appState.selectedTab = .progress
                },
                askAI: {
                    showQuickActions = false
                    appState.selectedTab = .coach
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Готово", isPresented: Binding(get: { !quickMessage.isEmpty }, set: { if !$0 { quickMessage = "" } })) {
            Button("OK") { quickMessage = "" }
        } message: {
            Text(quickMessage)
        }
    }
}

private struct UniversalQuickActionSheet: View {
    let addFood: () -> Void
    let addWater: () -> Void
    let addWeight: () -> Void
    let startWorkout: () -> Void
    let askAI: () -> Void

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(alignment: .leading, spacing: 18) {
                Text("Быстро добавить")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    actionRow(icon: "fork.knife", title: "Добавить еду", tint: AppColors.green, action: addFood)
                    actionRow(icon: "drop.fill", title: "Добавить воду", tint: AppColors.blue, action: addWater)
                    actionRow(icon: "scalemass", title: "Добавить вес", tint: AppColors.yellow, action: addWeight)
                    actionRow(icon: "dumbbell", title: "Начать тренировку", tint: AppColors.purple, action: startWorkout)
                    actionRow(icon: "robot", title: "Задать вопрос ИИ", tint: AppColors.purple, action: askAI)
                }
                Spacer()
            }
            .padding(22)
        }
    }

    private func actionRow(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemName: icon, tint: tint, size: 46)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.mutedText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.060))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
